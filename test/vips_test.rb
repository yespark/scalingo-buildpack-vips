require "test_helper"

class VipsFormatTest < Minitest::Test
  def test_loads_png_and_reads_dimensions
    result = pipeline.call(save: false)
    assert_dimensions [4, 4], result
    assert_equal 3, result.bands
  end

  def test_loads_tiff_image
    result = pipeline("test.tiff").call(save: false)
    assert_dimensions [4, 4], result
  end

  def test_loads_svg_image
    result = pipeline("test.svg").call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  def test_loads_pdf_as_image
    result = pipeline("test.pdf").call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  def test_loads_pdf_at_specific_dpi
    img_72  = pipeline("test.pdf").loader(dpi: 72).call(save: false)
    img_144 = pipeline("test.pdf").loader(dpi: 144).call(save: false)
    assert_equal img_72.width * 2, img_144.width
    assert_equal img_72.height * 2, img_144.height
  end

  def test_converts_pdf_to_png
    process_to_file("pdf_to_png.png") do |path|
      pipeline("test.pdf").convert("png").call(destination: path)
    end
  end

  def test_converts_pdf_to_jpeg
    process_to_file("pdf_to_jpeg.jpg") do |path|
      pipeline("test.pdf")
        .custom { |img| img.has_alpha? ? img.flatten(background: [255, 255, 255]) : img }
        .convert("jpg")
        .call(destination: path)
    end
  end

  def test_converts_png_to_jpeg
    process_to_file("converted.jpg") do |path|
      pipeline.convert("jpg").call(destination: path)
    end
  end

  def test_converts_png_to_webp
    process_to_file("converted.webp") do |path|
      pipeline.convert("webp").call(destination: path)
    end
  end

  def test_converts_png_to_tiff
    process_to_file("converted.tiff") do |path|
      pipeline.convert("tiff").call(destination: path)
    end
  end

  def test_converts_tiff_to_png
    process_to_file("tiff_to_png.png") do |path|
      pipeline("test.tiff").convert("png").call(destination: path)
    end
  end

  def test_converts_svg_to_png
    process_to_file("svg_to_png.png") do |path|
      pipeline("test.svg").convert("png").call(destination: path)
    end
  end
end

class VipsResizeTest < Minitest::Test
  def test_resize_to_limit
    result = pipeline.resize_to_fit(40, 40).resize_to_limit(20, 20).call(save: false)
    assert result.width <= 20
    assert result.height <= 20
  end

  def test_resize_to_fit
    result = pipeline.resize_to_fit(2, 2).call(save: false)
    assert result.width <= 2
    assert result.height <= 2
  end

  def test_resize_to_fill
    result = pipeline.resize_to_fit(40, 40).resize_to_fill(20, 20).call(save: false)
    assert_dimensions [20, 20], result
  end

  def test_resize_and_pad
    result = pipeline.resize_and_pad(30, 20, background: [255, 255, 255]).call(save: false)
    assert_dimensions [30, 20], result
  end

  def test_resize_to_cover
    result = pipeline.resize_to_cover(10, 10).call(save: false)
    assert result.width >= 10
    assert result.height >= 10
  end
end

class VipsManipulationTest < Minitest::Test
  def test_rotates_image_90_degrees
    result = pipeline.rotate(90).call(save: false)
    assert_dimensions [4, 4], result
  end

  def test_rotates_image_arbitrary_angle
    result = pipeline.rotate(45, background: [0, 0, 0]).call(save: false)
    assert result.width > 0
    assert result.height > 0
  end

  def test_crops_image
    result = pipeline.crop(1, 1, 2, 2).call(save: false)
    assert_dimensions [2, 2], result
  end

  def test_converts_to_greyscale
    result = pipeline.colourspace("b-w").call(save: false)
    assert_equal 1, result.bands
  end

  def test_inverts_image
    result = pipeline.invert.call(save: false)
    assert_equal 4, result.width
    assert_equal 3, result.bands
  end

  def test_applies_gaussian_blur
    result = pipeline.gaussblur(1.5).call(save: false)
    assert_dimensions [4, 4], result
  end

  def test_sharpens_image
    result = pipeline.sharpen.call(save: false)
    assert_equal 4, result.width
  end

  def test_composites_two_images
    overlay = pipeline.custom { |img| img.bandjoin(128) }.call(save: false)
    process_to_file("composited.png") do |path|
      pipeline.composite(overlay, mode: "over").convert("png").call(destination: path)
    end
  end

  def test_renders_text_to_image
    result = pipeline.custom { |_| Vips::Image.text("Hello", dpi: 72) }.call(save: false)
    assert result.width > 0
    assert result.height > 0
  end
end

class VipsMetadataTest < Minitest::Test
  def test_reads_image_metadata_fields
    result = pipeline.call(save: false)
    assert_equal 4, result.get("width")
    assert_equal 4, result.get("height")
    assert_equal 3, result.get("bands")
  end
end

class VipsSaverTest < Minitest::Test
  def test_jpeg_quality
    high_q = pipeline.resize_to_fit(40, 40).convert("jpg").saver(Q: 95).call
    low_q  = pipeline.resize_to_fit(40, 40).convert("jpg").saver(Q: 30).call
    assert File.size(high_q.path) > File.size(low_q.path),
      "higher quality should produce larger file"
  end

  def test_png_compression
    low_c  = pipeline.resize_to_fit(40, 40).convert("png").saver(compression: 1).call
    high_c = pipeline.resize_to_fit(40, 40).convert("png").saver(compression: 9).call
    assert File.size(low_c.path) >= File.size(high_c.path),
      "higher compression should produce smaller or equal file"
  end

  def test_webp_lossy
    result = pipeline.convert("webp").saver(Q: 50).call
    assert File.size(result.path) > 0
  end

  def test_webp_lossless
    result = pipeline.convert("webp").saver(lossless: true).call
    assert File.size(result.path) > 0
  end

  def test_jpeg_strip_metadata
    result = pipeline.convert("jpg").saver(strip: true).call
    assert File.size(result.path) > 0
  end

  def test_jpeg_interlace_progressive
    result = pipeline.convert("jpg").saver(interlace: true).call
    assert File.size(result.path) > 0
  end
end

class VipsHeifTest < Minitest::Test
  def test_converts_png_to_heif
    process_to_file("converted.heif") do |path|
      pipeline.convert("heif").call(destination: path)
    end
  end

  def test_heif_round_trip_preserves_dimensions
    heif_path = File.join(OUT_DIR, "roundtrip.heif")
    pipeline.convert("heif").call(destination: heif_path)
    reloaded = ImageProcessing::Vips.source(heif_path).call(save: false)
    assert_dimensions [4, 4], reloaded
  end

  def test_saves_heic_to_file_and_reloads
    heic_path = File.join(OUT_DIR, "output.heic")
    pipeline.convert("heic").call(destination: heic_path)
    assert File.size(heic_path) > 0
    reloaded = ImageProcessing::Vips.source(heic_path).call(save: false)
    assert_equal 4, reloaded.width
  end

  def test_converts_heif_to_png
    heif_path = File.join(OUT_DIR, "intermediate.heif")
    pipeline.convert("heif").call(destination: heif_path)
    process_to_file("heif_to_png.png") do |path|
      ImageProcessing::Vips.source(heif_path).convert("png").call(destination: path)
    end
  end

  def test_converts_heic_to_jpeg
    heic_path = File.join(OUT_DIR, "intermediate.heic")
    pipeline.convert("heic").call(destination: heic_path)
    process_to_file("heic_to_jpeg.jpg") do |path|
      ImageProcessing::Vips.source(heic_path).convert("jpg").call(destination: path)
    end
  end

  def test_heif_works_without_modules
    result = pipeline.convert("heif").call
    assert File.size(result.path) > 0
    reloaded = ImageProcessing::Vips.source(result.path).call(save: false)
    assert_equal 4, reloaded.width

    vips_prefix = "/app/vendor/vips"
    module_dirs = Dir.glob(File.join(vips_prefix, "lib", "vips-modules-*"))
    assert_empty module_dirs, "vips-modules directory should not exist when modules are disabled"
  end
end

class VipsPipelineTest < Minitest::Test
  def test_resize_then_convert_to_webp
    result = pipeline.resize_to_fit(8, 8).gaussblur(1.0).convert("webp").call
    assert File.size(result.path) > 0
  end

  def test_crop_greyscale_and_save_as_jpeg
    result = pipeline.crop(0, 0, 3, 3).colourspace("b-w").convert("jpg").call(save: false)
    assert_equal 1, result.bands
    assert_equal 3, result.width
  end

  def test_validates_image_file
    assert ImageProcessing::Vips.valid_image?(fixture_image("test.png"))
  end
end
