ENV["VIPS_WARNING"] = "0"

require "minitest/autorun"
require "image_processing/vips"
require "fileutils"

class Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)
  OUT_DIR  = File.join(Dir.tmpdir, "vips_test_output")

  def setup
    FileUtils.mkdir_p(OUT_DIR)
  end

  private

  def fixture_image(name)
    File.open(File.join(FIXTURES, name), "rb")
  end

  def pipeline(fixture = "test.png")
    ImageProcessing::Vips.source(File.join(FIXTURES, fixture))
  end

  def process_to_file(filename)
    path = File.join(OUT_DIR, filename)
    yield path
    assert File.size(path) > 0, "#{filename} should be non-empty"
    path
  end

  def assert_dimensions(expected_dims, result)
    assert_equal expected_dims, [result.width, result.height]
  end
end
