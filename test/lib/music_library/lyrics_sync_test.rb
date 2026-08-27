require "test_helper"
require "music_library/lyrics_sync"

class MusicLibrary::LyricsSynchronizerTest < ActiveSupport::TestCase
  setup do
    @directory = Pathname(Dir.mktmpdir)
    @audio_path = @directory.join("01 - A Song.mp3")
    @audio_path.write("audio")
    @track = MusicLibrary::LyricTrackData.new(path: @audio_path.to_s, title: "A Song", artist: "An Artist", album: "An Album", duration: 180, isrc: nil)
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test "reports a synchronized lyric file in dry-run mode without writing it" do
    result = synchronizer.call.first

    assert_equal :ready, result.status
    assert_equal "line", result.sync_level
    assert_not @audio_path.sub_ext(".lrc").exist?
  end

  test "writes an LRC sidecar when explicitly enabled" do
    result = synchronizer(write: true).call.first

    assert_equal :written, result.status
    assert_equal "[00:17.19] First line\n[01:02.42] Second line\n", @audio_path.sub_ext(".lrc").read
  end

  test "skips an existing sidecar unless overwrite is requested" do
    @audio_path.sub_ext(".lrc").write("Existing lyrics\n")

    result = synchronizer.call.first

    assert_equal :skipped, result.status
    assert_equal "Existing lyrics\n", @audio_path.sub_ext(".lrc").read
  end

  test "rejects a likely different recording" do
    lookup = lookup_result(matched_duration: 220)
    result = synchronizer(lyrics_client: fake_client(lookup)).call.first

    assert_equal :missing, result.status
    assert_not @audio_path.sub_ext(".lrc").exist?
  end

  test "reports progress before each audio file is synchronized" do
    updates = []

    synchronizer(progress: ->(update) { updates << update }).call

    assert_equal 1, updates.size
    assert_equal 1, updates.first.current
    assert_equal 1, updates.first.total
    assert_equal @audio_path.to_s, updates.first.path
  end

  test "checks write access before requesting any lyrics" do
    writer = Object.new
    writer.define_singleton_method(:verify!) { |_| raise MusicLibrary::SidecarWriter::WriteAccessError, "Read-only file system" }
    client = Object.new
    client.define_singleton_method(:fetch) { |_, allow_plain:| flunk "Lyrics lookup should not run" }

    assert_raises(MusicLibrary::SidecarWriter::WriteAccessError) do
      synchronizer(write: true, lyrics_client: client, sidecar_writer: writer).call
    end
  end

  test "stops immediately if an atomic sidecar write fails" do
    writer = Object.new
    writer.define_singleton_method(:verify!) { |_| nil }
    writer.define_singleton_method(:write) { |_, _| raise MusicLibrary::SidecarWriter::WriteAccessError, "Connection lost" }

    assert_raises(MusicLibrary::SidecarWriter::WriteAccessError) do
      synchronizer(write: true, sidecar_writer: writer).call
    end
  end

  private

  def synchronizer(write: false, lyrics_client: fake_client(lookup_result), sidecar_writer: MusicLibrary::SidecarWriter.new, progress: nil)
    MusicLibrary::LyricsSynchronizer.new(
      root: @directory,
      metadata_reader: fake_reader,
      lyrics_client: lyrics_client,
      sidecar_writer: sidecar_writer,
      write: write,
      delay: 0,
      progress: progress
    )
  end

  def fake_reader
    Object.new.tap { |reader| reader.define_singleton_method(:read) { |_| @track } }.tap { |reader| reader.instance_variable_set(:@track, @track) }
  end

  def fake_client(response)
    Object.new.tap { |client| client.define_singleton_method(:fetch) { |_, allow_plain:| response } }
  end

  def lookup_result(matched_duration: 180)
    MusicLibrary::LyricLookupResultData.new(
      lines: [ { text: "First line", start: 17_190 }, { text: "Second line", start: 62_420 } ],
      sync_level: "line",
      matched_title: "A Song",
      matched_artist: "An Artist",
      matched_album: "An Album",
      matched_duration: matched_duration
    )
  end
end
