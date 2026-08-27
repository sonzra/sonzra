require "json"
require "net/http"
require "open3"
require "pathname"
require "tempfile"
require "uri"

module MusicLibrary
  LyricTrackData = Data.define(:path, :title, :artist, :album, :duration, :isrc)
  LyricLookupResultData = Data.define(:lines, :sync_level, :matched_title, :matched_artist, :matched_album, :matched_duration)
  LyricSyncResultData = Data.define(:path, :status, :message, :sync_level)
  LyricsSyncProgressData = Data.define(:current, :total, :path)

  class AudioMetadataReader
    def read(path)
      output, status = Open3.capture2(
        "ffprobe", "-v", "error", "-show_entries", "format=duration:format_tags=title,artist,album,isrc,ISRC", "-of", "json", path
      )
      raise "ffprobe could not read #{path}" unless status.success?

      format = JSON.parse(output).fetch("format")
      tags = format.fetch("tags", {}).transform_keys(&:downcase)
      LyricTrackData.new(
        path: path,
        title: tags["title"],
        artist: tags["artist"],
        album: tags["album"],
        duration: format.fetch("duration", 0).to_f,
        isrc: tags["isrc"]
      )
    rescue JSON::ParserError, KeyError
      raise "ffprobe returned invalid metadata for #{path}"
    end
  end

  class LrcmuxClient
    ENDPOINT = URI("https://api.lrcmux.dev/get")

    def initialize(http: Net::HTTP, endpoint: ENDPOINT)
      @http = http
      @endpoint = endpoint
    end

    def fetch(track, allow_plain: false)
      uri = @endpoint.dup
      parameters = {
        title: track.title,
        artist: track.artist,
        album: track.album,
        isrc: track.isrc,
        duration: track.duration.round,
        level: "line",
        strict: !allow_plain,
        format: "json"
      }.compact
      uri.query = URI.encode_www_form(parameters)
      response = perform(Net::HTTP::Get.new(uri, "User-Agent" => "Sonzra lyrics sync (https://github.com/sonzra/sonzra)"))
      return nil if response.code.to_i == 404

      raise "LRCmux returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      LyricLookupResultData.new(
        lines: payload.fetch("lines", []).filter_map { |line| normalize_line(line) },
        sync_level: payload.dig("meta", "level"),
        matched_title: payload.dig("track", "title"),
        matched_artist: payload.dig("track", "artist"),
        matched_album: payload.dig("track", "album"),
        matched_duration: payload.dig("track", "duration")&.to_f
      )
    rescue JSON::ParserError, KeyError
      raise "LRCmux returned an invalid response"
    end

    private

    def normalize_line(line)
      text = line.fetch("text", "").to_s.strip
      return if text.empty?

      { text: text, start: line["start"]&.to_f }
    end

    def perform(request)
      @http.start(request.uri.host, request.uri.port, use_ssl: request.uri.scheme == "https", open_timeout: 5, read_timeout: 20) do |connection|
        connection.request(request)
      end
    end
  end

  class SidecarWriter
    class WriteAccessError < StandardError; end

    def verify!(paths)
      paths.map(&:dirname).uniq.each { |directory| verify_directory!(directory) }
    end

    def write(path, content)
      temporary_file = Tempfile.create([ ".sonzra-lyrics-", ".tmp" ], path.dirname)
      temporary_file.write(content)
      temporary_file.flush
      temporary_file.fsync
      temporary_file.close
      File.rename(temporary_file.path, path)
    rescue SystemCallError, IOError => error
      raise WriteAccessError, "Could not write #{path}: #{error.message}"
    ensure
      temporary_file&.close unless temporary_file&.closed?
      File.delete(temporary_file.path) if temporary_file && File.exist?(temporary_file.path)
    end

    private

    def verify_directory!(directory)
      temporary_file = Tempfile.create([ ".sonzra-lyrics-write-check-", ".tmp" ], directory)
      temporary_file.write("write check\n")
      temporary_file.flush
      temporary_file.fsync
    rescue SystemCallError, IOError => error
      raise WriteAccessError, "Cannot write to #{directory}: #{error.message}"
    ensure
      temporary_file&.close unless temporary_file&.closed?
      File.delete(temporary_file.path) if temporary_file && File.exist?(temporary_file.path)
    end
  end

  class LyricsSynchronizer
    AUDIO_EXTENSIONS = %w[.aac .flac .m4a .mp3 .ogg .opus .wav].freeze
    MAX_DURATION_DIFFERENCE = 12

    def initialize(root:, metadata_reader: AudioMetadataReader.new, lyrics_client: LrcmuxClient.new, sidecar_writer: SidecarWriter.new, write: false, overwrite: false, allow_plain: false, delay: 1, progress: nil)
      @root = Pathname(root)
      @metadata_reader = metadata_reader
      @lyrics_client = lyrics_client
      @sidecar_writer = sidecar_writer
      @write = write
      @overwrite = overwrite
      @allow_plain = allow_plain
      @delay = delay
      @progress = progress
    end

    def call
      paths = audio_files
      @sidecar_writer.verify!(paths) if @write

      paths.map.with_index do |path, index|
        @progress&.call(LyricsSyncProgressData.new(current: index + 1, total: paths.size, path: path.to_s))
        sleep @delay if index.positive? && @delay.positive?
        synchronize(path)
      end
    end

    private

    def audio_files
      @root.glob("**/*").select { |path| path.file? && AUDIO_EXTENSIONS.include?(path.extname.downcase) }.sort
    end

    def synchronize(path)
      lrc_path = path.sub_ext(".lrc")
      return result(path, :skipped, "Sidecar already exists") if lrc_path.exist? && !@overwrite

      track = @metadata_reader.read(path.to_s)
      return result(path, :skipped, "Missing title or artist") if track.title.to_s.strip.empty? || track.artist.to_s.strip.empty?

      lyrics = @lyrics_client.fetch(track, allow_plain: @allow_plain)
      return result(path, :missing, "No lyrics found") unless usable?(track, lyrics)

      lrc = LrcFormatter.new(lyrics.lines).render
      @sidecar_writer.write(lrc_path, lrc) if @write
      result(path, @write ? :written : :ready, @write ? "Lyrics written" : "Lyrics ready (dry run)", lyrics.sync_level)
    rescue SidecarWriter::WriteAccessError
      raise
    rescue StandardError => error
      result(path, :failed, error.message)
    end

    def usable?(track, lyrics)
      return false if lyrics.nil? || lyrics.lines.empty?
      return false unless same_title?(track.title, lyrics.matched_title)
      return false if lyrics.matched_duration && (track.duration - lyrics.matched_duration).abs > MAX_DURATION_DIFFERENCE

      @allow_plain || %w[line word].include?(lyrics.sync_level)
    end

    def same_title?(first, second)
      normalize(first) == normalize(second)
    end

    def normalize(value)
      value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]/, "")
    end

    def result(path, status, message, sync_level = nil)
      LyricSyncResultData.new(path: path.to_s, status: status, message: message, sync_level: sync_level)
    end
  end

  class LrcFormatter
    def initialize(lines)
      @lines = lines
    end

    def render
      @lines.map { |line| format_line(line) }.join("\n") + "\n"
    end

    private

    def format_line(line)
      return line.fetch(:text) if line[:start].nil?

      total_centiseconds = (line.fetch(:start) / 10).round
      minutes, centiseconds = total_centiseconds.divmod(6_000)
      seconds, centiseconds = centiseconds.divmod(100)
      format("[%02d:%02d.%02d] %s", minutes, seconds, centiseconds, line.fetch(:text))
    end
  end

  LyricsSync = LyricsSynchronizer
end
