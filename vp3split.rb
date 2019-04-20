file = File.open("test.vp3", "rb")

# Header
magic_string = file.read(6)
abort("Invalid magic_string") unless magic_string == "%vsm%\x00"
production_string_length = file.read(2).unpack("n").first
production_string = file.read(production_string_length)

# EmbroiderySummary
tag = file.read(3)
abort("Invalid EmbroiderySummary tag") unless tag == "\x00\x02\x00"
bytes_to_eof = file.read(4).unpack("N")
settings_string_length = file.read(2).unpack("n").first
settings_string = file.read(settings_string_length)

# Extend
extend_right = file.read(4).unpack("N")
extend_top = file.read(4).unpack("N")
extend_left = file.read(4).unpack("N")
extend_bottom = file.read(4).unpack("N")

stitch_time = file.read(4).unpack("N")

thread_change_count = file.read(2).unpack("n").first
puts "There are #{thread_change_count} colors in all designs"

unknown_c = file.read(1).unpack("h").first
abort("Invalid unknown_c") unless unknown_c == "c"

design_block_count = file.read(2).unpack("n").first
puts "Designs in this file: #{design_block_count}"

# Design block
design_block_count.times do

  tag = file.read(3)
  abort("Invalid DesignBlock tag") unless tag == "\x00\x03\x00"

  bytes_to_end_of_design = file.read(4).unpack("N")

  design_center_x = file.read(4).unpack("N")
  design_center_y = file.read(4).unpack("N")

  unknown_000_1 = file.read(3)
  abort("Invalid unknown_000_1 element") unless unknown_000_1 == "\x00\x00\x00"

  min_half_width = file.read(4).unpack("N")
  plus_half_width = file.read(4).unpack("N")
  min_half_heigth = file.read(4).unpack("N")
  plus_half_heigth = file.read(4).unpack("N")
  width = file.read(4).unpack("N")
  height = file.read(4).unpack("N")

  design_notes_string_length = file.read(2).unpack("n").first
  design_notes_string = file.read(design_notes_string_length)

  unknown_dd = file.read(2)
  abort("Invalid unknown_dd element") unless unknown_dd == "dd"
  unknown_101 = file.read(16)
  abort("Invalid unknown_101 element") unless unknown_101 == "\x00\x00\x10\x00" + "\x00\x00\x00\x00" + "\x00\x00\x00\x00" + "\x00\x00\x10\x00"
  unknown_xxpp = file.read(4)
  abort("Invalid unknown_xxpp element") unless unknown_xxpp == "xxPP"
  unknown_10 = file.read(2)
  abort("Invalid unknown_10 element") unless unknown_10 == "\x01\x00"

  production_string_length = file.read(2).unpack("n").first
  production_string = file.read(production_string_length)

  color_block_count = file.read(2).unpack("n").first
  puts "This design has #{color_block_count} colors"

  # Color block
  color_block_count.times do |color_nr|

    puts
    puts "Color \##{color_nr + 1}"

    tag = file.read(3)
    abort("Invalid ColorBlock tag") unless tag == "\x00\x05\x00"

    bytes_to_next_color_block = file.read(4).unpack("N").first
    color_block_data = file.read(bytes_to_next_color_block)

    color_entries = color_block_data[8].unpack("C").first
    abort("Thread colors is #{color_entries} instead of 1") unless color_entries == 1

    print "Material: "
    case material = color_block_data[16].unpack("C").first
    when 3
      puts "Metallic"
    when 4
      puts "Cotton"
    when 5
      puts "Rayon"
    when 6
      puts "Polyester"
    when 10
      puts "Silk"
    else
      puts "Unknown material"
    end

    weight = color_block_data[17].unpack("C").first
    puts "Weight: #{weight}"

    catalog_length = color_block_data[18..19].unpack("n").first
    catalog = color_block_data[20, catalog_length]
    puts "Catalog: #{catalog}"

    offset = 20 + catalog_length
    description_length = color_block_data[offset, 2].unpack("n").first
    offset += 2
    description = color_block_data[offset, description_length]
    puts "Description: #{description}"

    offset += description_length
    brand_length = color_block_data[offset, 2].unpack("n").first
    offset += 2
    brand = color_block_data[offset, brand_length]
    puts "Brand: #{brand}"

  end

end