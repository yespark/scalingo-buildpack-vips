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

class VipsActiveStorageVariantTest < Minitest::Test
  # Mirrors what Active Storage does under the hood for:
  #   has_one_attached :image do |attachable|
  #     attachable.variant :large,  resize_to_fill: [756, 504], format: "jpg", quality: 80, strip: true
  #     attachable.variant :medium, resize_to_fill: [558, 372], format: "jpg", quality: 80, strip: true
  #     attachable.variant :small,  resize_to_fill: [405, 270], format: "jpg", quality: 80, strip: true
  #   end

  VARIANTS = {
    large:  [756, 504],
    medium: [558, 372],
    small:  [405, 270],
  }.freeze

  def test_resize_to_fill_convert_quality_strip_pipeline
    VARIANTS.each do |name, (width, height)|
      process_to_file("variant_#{name}.jpg") do |path|
        pipeline
          .loader(page: 0)
          .resize_to_fill(width, height)
          .convert("jpg")
          .saver(Q: 80, strip: true)
          .call(destination: path)
      end

      result = Vips::Image.new_from_file(File.join(OUT_DIR, "variant_#{name}.jpg"))
      assert_dimensions [width, height], result
    end
  end

  def test_all_variant_sizes_from_same_source
    sizes = VARIANTS.map do |name, (width, height)|
      path = File.join(OUT_DIR, "multi_#{name}.jpg")
      pipeline
        .loader(page: 0)
        .resize_to_fill(width, height)
        .convert("jpg")
        .saver(Q: 80, strip: true)
        .call(destination: path)
      File.size(path)
    end

    assert sizes[0] > sizes[1], "large variant should be bigger than medium"
    assert sizes[1] > sizes[2], "medium variant should be bigger than small"
  end

  def test_strip_removes_metadata
    with_meta = pipeline.convert("jpg").saver(Q: 80, strip: false).call
    stripped  = pipeline.convert("jpg").saver(Q: 80, strip: true).call

    img_with = Vips::Image.new_from_file(with_meta.path)
    img_sans = Vips::Image.new_from_file(stripped.path)

    # stripped file should have no EXIF or ICC profile fields
    has_exif = img_sans.get_typeof("exif-data") != 0
    has_icc  = img_sans.get_typeof("icc-profile-data") != 0
    refute has_exif, "stripped image should not contain EXIF data"
    refute has_icc, "stripped image should not contain ICC profile"
  end

  def test_png_alpha_to_jpg_via_resize_to_fill
    # Active Storage doesn't flatten alpha — vips handles it by dropping the
    # alpha channel on JPEG save. Verify this doesn't error or corrupt output.
    process_to_file("alpha_to_jpg.jpg") do |path|
      pipeline
        .loader(page: 0)
        .resize_to_fill(100, 100)
        .convert("jpg")
        .saver(Q: 80, strip: true)
        .call(destination: path)
    end

    result = Vips::Image.new_from_file(File.join(OUT_DIR, "alpha_to_jpg.jpg"))
    assert_dimensions [100, 100], result
    assert_equal 3, result.bands, "JPEG should have 3 bands (no alpha)"
  end

  def test_loader_page_zero_on_raster_image
    result = pipeline
      .loader(page: 0)
      .resize_to_fill(2, 2)
      .call(save: false)
    assert_dimensions [2, 2], result
  end

  def test_pdf_variant_pipeline
    process_to_file("pdf_variant.jpg") do |path|
      pipeline("test.pdf")
        .loader(page: 0)
        .resize_to_fill(405, 270)
        .convert("jpg")
        .saver(Q: 80, strip: true)
        .call(destination: path)
    end

    result = Vips::Image.new_from_file(File.join(OUT_DIR, "pdf_variant.jpg"))
    assert_dimensions [405, 270], result
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
