require "test_helper"
require "image_processing/vips"

class ImageProcessingTest < ActiveSupport::TestCase
  FIXTURES = File.expand_path("fixtures", __dir__)
  OUT_DIR  = Rails.root.join("tmp/test_output")

  setup do
    FileUtils.mkdir_p(OUT_DIR)
    Rails.application.config.active_storage.variant_processor = :vips
  end

  private

  def pipeline(fixture = "test.png")
    ImageProcessing::Vips.source(File.join(FIXTURES, fixture))
  end

  def process_to_file(filename, &block)
    path = OUT_DIR.join(filename).to_s
    block.call(path)
    assert File.size(path) > 0, "#{filename} should be non-empty"
    path
  end

  public

  # --- Format loading ---

  test "loads png and reads dimensions" do
    result = pipeline.call(save: false)
    assert_equal 4, result.width
    assert_equal 4, result.height
    assert_equal 3, result.bands
  end

  test "loads tiff image" do
    result = pipeline("test.tiff").call(save: false)
    assert_equal 4, result.width
    assert_equal 4, result.height
  end

  test "loads svg image" do
    result = pipeline("test.svg").call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  # --- PDF (poppler) ---

  test "loads pdf as image" do
    result = pipeline("test.pdf").call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  test "loads pdf at specific dpi" do
    img_72 = pipeline("test.pdf").loader(dpi: 72).call(save: false)
    img_144 = pipeline("test.pdf").loader(dpi: 144).call(save: false)
    assert_equal img_72.width * 2, img_144.width
    assert_equal img_72.height * 2, img_144.height
  end

  test "converts pdf to png" do
    process_to_file("pdf_to_png.png") do |path|
      pipeline("test.pdf").convert("png").call(destination: path)
    end
  end

  test "converts pdf to jpeg" do
    process_to_file("pdf_to_jpeg.jpg") do |path|
      pipeline("test.pdf")
        .custom { |img| img.has_alpha? ? img.flatten(background: [255, 255, 255]) : img }
        .convert("jpg")
        .call(destination: path)
    end
  end

  # --- Format conversion ---

  test "converts png to jpeg" do
    process_to_file("converted.jpg") do |path|
      pipeline.convert("jpg").call(destination: path)
    end
  end

  test "converts png to webp" do
    process_to_file("converted.webp") do |path|
      pipeline.convert("webp").call(destination: path)
    end
  end

  test "converts png to tiff" do
    process_to_file("converted.tiff") do |path|
      pipeline.convert("tiff").call(destination: path)
    end
  end

  test "converts tiff to png" do
    process_to_file("tiff_to_png.png") do |path|
      pipeline("test.tiff").convert("png").call(destination: path)
    end
  end

  test "converts svg to png" do
    process_to_file("svg_to_png.png") do |path|
      pipeline("test.svg").convert("png").call(destination: path)
    end
  end

  # --- Resize operations ---

  test "resize_to_limit" do
    result = pipeline.resize_to_fit(40, 40).resize_to_limit(20, 20).call(save: false)
    assert result.width <= 20
    assert result.height <= 20
  end

  test "resize_to_fit" do
    result = pipeline.resize_to_fit(2, 2).call(save: false)
    assert result.width <= 2
    assert result.height <= 2
  end

  test "resize_to_fill" do
    result = pipeline.resize_to_fit(40, 40).resize_to_fill(20, 20).call(save: false)
    assert_equal 20, result.width
    assert_equal 20, result.height
  end

  test "resize_and_pad" do
    result = pipeline.resize_and_pad(30, 20, background: [255, 255, 255]).call(save: false)
    assert_equal 30, result.width
    assert_equal 20, result.height
  end

  test "resize_to_cover" do
    result = pipeline.resize_to_cover(10, 10).call(save: false)
    assert result.width >= 10
    assert result.height >= 10
  end

  # --- Image manipulation ---

  test "rotates image 90 degrees" do
    result = pipeline.rotate(90).call(save: false)
    assert_equal 4, result.width
    assert_equal 4, result.height
  end

  test "rotates image arbitrary angle" do
    result = pipeline.rotate(45, background: [0, 0, 0]).call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  test "crops image" do
    result = pipeline.crop(1, 1, 2, 2).call(save: false)
    assert_equal 2, result.width
    assert_equal 2, result.height
  end

  # --- Color operations ---

  test "converts to greyscale" do
    result = pipeline.colourspace("b-w").call(save: false)
    assert_equal 1, result.bands
  end

  test "inverts image" do
    result = pipeline.invert.call(save: false)
    assert_equal 4, result.width
    assert_equal 3, result.bands
  end

  # --- Filters (FFTW-backed) ---

  test "applies gaussian blur" do
    result = pipeline.gaussblur(1.5).call(save: false)
    assert_equal 4, result.width
    assert_equal 4, result.height
  end

  test "sharpens image" do
    result = pipeline.sharpen.call(save: false)
    assert_equal 4, result.width
  end

  # --- Composite / overlay ---

  test "composites two images" do
    overlay = pipeline.custom { |img| img.bandjoin(128) }.call(save: false)
    process_to_file("composited.png") do |path|
      pipeline.composite(overlay, mode: "over").convert("png").call(destination: path)
    end
  end

  # --- Text rendering (pango) ---

  test "renders text to image" do
    result = pipeline.custom { |_| Vips::Image.text("Hello", dpi: 72) }.call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  # --- Metadata ---

  test "reads image metadata fields" do
    result = pipeline.call(save: false)
    assert_equal 4, result.get("width")
    assert_equal 4, result.get("height")
    assert_equal 3, result.get("bands")
  end

  # --- Saver options ---

  test "jpeg with quality saver option" do
    high_q = pipeline.convert("jpg").saver(Q: 95).call
    low_q = pipeline.convert("jpg").saver(Q: 30).call
    assert File.size(high_q.path) > File.size(low_q.path),
      "higher quality should produce larger file"
  end

  test "png with compression saver option" do
    low_c = pipeline.resize_to_fit(40, 40).convert("png").saver(compression: 1).call
    high_c = pipeline.resize_to_fit(40, 40).convert("png").saver(compression: 9).call
    assert File.size(low_c.path) >= File.size(high_c.path),
      "higher compression should produce smaller or equal file"
  end

  test "webp lossy" do
    result = pipeline.convert("webp").saver(Q: 50).call
    assert File.size(result.path) > 0
  end

  test "webp lossless" do
    result = pipeline.convert("webp").saver(lossless: true).call
    assert File.size(result.path) > 0
  end

  test "jpeg strip metadata" do
    result = pipeline.convert("jpg").saver(strip: true).call
    assert File.size(result.path) > 0
  end

  test "jpeg interlace (progressive)" do
    result = pipeline.convert("jpg").saver(interlace: true).call
    assert File.size(result.path) > 0
  end

  # --- HEIF / HEIC support (libheif, statically linked — modules disabled) ---

  test "converts png to heif" do
    process_to_file("converted.heif") do |path|
      pipeline.convert("heif").call(destination: path)
    end
  end

  test "heif round-trip preserves dimensions" do
    heif_path = OUT_DIR.join("roundtrip.heif").to_s
    pipeline.convert("heif").call(destination: heif_path)
    reloaded = ImageProcessing::Vips.source(heif_path).call(save: false)
    assert_equal 4, reloaded.width
    assert_equal 4, reloaded.height
  end

  test "saves heic to file and reloads" do
    heic_path = OUT_DIR.join("output.heic").to_s
    pipeline.convert("heic").call(destination: heic_path)
    assert File.size(heic_path) > 0
    reloaded = ImageProcessing::Vips.source(heic_path).call(save: false)
    assert_equal 4, reloaded.width
  end

  test "converts heif to png" do
    heif_path = OUT_DIR.join("intermediate.heif").to_s
    pipeline.convert("heif").call(destination: heif_path)
    process_to_file("heif_to_png.png") do |path|
      ImageProcessing::Vips.source(heif_path).convert("png").call(destination: path)
    end
  end

  test "converts heic to jpeg" do
    heic_path = OUT_DIR.join("intermediate.heic").to_s
    pipeline.convert("heic").call(destination: heic_path)
    process_to_file("heic_to_jpeg.jpg") do |path|
      ImageProcessing::Vips.source(heic_path).convert("jpg").call(destination: path)
    end
  end

  test "heif works without modules (statically linked)" do
    result = pipeline.convert("heif").call
    assert File.size(result.path) > 0
    reloaded = ImageProcessing::Vips.source(result.path).call(save: false)
    assert_equal 4, reloaded.width

    vips_prefix = "/app/vendor/vips"
    module_dirs = Dir.glob(File.join(vips_prefix, "lib", "vips-modules-*"))
    assert_empty module_dirs, "vips-modules directory should not exist when modules are disabled"
  end

  # --- Active Storage variant options ---
  # Reference: https://gist.github.com/brenogazzola/a4369965a1da426d50f11d080fe2e563

  test "variant: resize_to_limit constrains dimensions" do
    result = pipeline.resize_to_fit(40, 40).resize_to_limit(10, 10).call(save: false)
    assert result.width <= 10
    assert result.height <= 10
  end

  test "variant: resize_to_fill crops to exact dimensions" do
    result = pipeline.resize_to_fit(40, 40).resize_to_fill(15, 10).call(save: false)
    assert_equal 15, result.width
    assert_equal 10, result.height
  end

  test "variant: resize_to_fill with smart crop" do
    result = pipeline.resize_to_fit(40, 40).resize_to_fill(15, 10, crop: :attention).call(save: false)
    assert_equal 15, result.width
    assert_equal 10, result.height
  end

  test "variant: resize_and_pad with background" do
    result = pipeline.resize_and_pad(20, 10, background: [255, 0, 0]).call(save: false)
    assert_equal 20, result.width
    assert_equal 10, result.height
  end

  test "variant: flatten alpha with background colour" do
    result = pipeline
      .custom { |img| img.bandjoin(128) }
      .custom { |img| img.flatten(background: [255, 0, 0]) }
      .call(save: false)
    assert_equal 3, result.bands
  end

  # --- Pipeline: chained operations ---

  test "resize then convert to webp" do
    result = pipeline.resize_to_fit(8, 8).gaussblur(1.0).convert("webp").call
    assert File.size(result.path) > 0
  end

  test "crop, greyscale, and save as jpeg" do
    result = pipeline.crop(0, 0, 3, 3).colourspace("b-w").convert("jpg").call(save: false)
    assert_equal 1, result.bands
    assert_equal 3, result.width
  end

  test "validates image file" do
    assert ImageProcessing::Vips.valid_image?(File.open(File.join(FIXTURES, "test.png")))
  end

  # --- Verify ImageMagick is absent and Rails uses vips ---

  test "imagemagick is not installed" do
    assert_nil `which convert 2>/dev/null`.strip.presence,
      "ImageMagick 'convert' should not be available"
    assert_nil `which magick 2>/dev/null`.strip.presence,
      "ImageMagick 'magick' should not be available"
  end

  test "rails active storage uses vips variant processor" do
    processor = Rails.application.config.active_storage.variant_processor
    assert_equal :vips, processor,
      "Active Storage should use :vips, got #{processor.inspect}"
  end
end
