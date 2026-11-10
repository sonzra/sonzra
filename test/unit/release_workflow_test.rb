require "test_helper"
require "yaml"

class ReleaseWorkflowTest < ActiveSupport::TestCase
  setup do
    @release_workflow_path = Rails.root.join(".github/workflows/release.yml")
    @publish_workflow_path = Rails.root.join(".github/workflows/publish-image.yml")
  end

  test "publish-image workflow supports workflow_dispatch and workflow_call with tag input" do
    config = YAML.safe_load(File.read(@publish_workflow_path))
    triggers = config["on"] || config[true]

    assert triggers.key?("workflow_dispatch"), "publish-image.yml must support workflow_dispatch for manual backfills"
    assert triggers.key?("workflow_call"), "publish-image.yml must support workflow_call for chaining from release.yml"
    assert triggers.dig("workflow_dispatch", "inputs", "tag").present?, "workflow_dispatch must declare a tag input"
    assert triggers.dig("workflow_call", "inputs", "tag").present?, "workflow_call must declare a tag input"
  end

  test "release workflow exports outputs and chains container image publishing" do
    config = YAML.safe_load(File.read(@release_workflow_path))

    release_job = config.dig("jobs", "release")
    assert release_job.present?, "release.yml must define a release job"
    assert_equal "${{ steps.release.outputs.version }}", release_job.dig("outputs", "version"), "release job must export version output"
    assert_equal "${{ steps.release.outputs.tag }}", release_job.dig("outputs", "tag"), "release job must export tag output"

    publish_job = config.dig("jobs", "publish")
    assert publish_job.present?, "release.yml must chain a publish job to publish container images"
    assert_equal "release", publish_job["needs"], "publish job must depend on release job completing"
    assert_equal "./.github/workflows/publish-image.yml", publish_job["uses"], "publish job must reuse publish-image.yml"
    assert_equal "${{ needs.release.outputs.tag }}", publish_job.dig("with", "tag"), "publish job must forward release tag"
  end
end
