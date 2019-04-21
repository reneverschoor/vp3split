class Header
  @file = nil

  attr_reader :data_size

  def initialize(file)
    @file = file
    @data_size = 0
    read_data
  end

  def read_data
    magic_string = @file.read(6)
    @data_size += 6
    abort('Invalid magic_string') unless magic_string == "%vsm%\x00"

    production_string_length = @file.read(2).unpack('n').first
    @data_size += 2
    production_string = @file.read(production_string_length)
    @data_size += production_string_length
  end
end

class EmbroiderySummary
  @file = nil

  attr_reader :data_size
  attr_reader :cursor_bytes_to_eof

  def initialize(file)
    @file = file
    @data_size = 0
    read_data
  end

  def read_data
    tag = @file.read(3)
    @data_size += 3
    abort('Invalid EmbroiderySummary tag') unless tag == "\x00\x02\x00"

    cursor_bytes_to_eof = @file.tell
    bytes_to_eof = @file.read(4).unpack('N').first   # needs to be modified
    @data_size += 4

    settings_string_length = @file.read(2).unpack('n').first
    @data_size += 2
    settings_string = @file.read(settings_string_length)
    @data_size += settings_string_length
  end
end

class Extend
  @file = nil

  attr_reader :cursor_thread_change_count
  attr_reader :cursor_design_block_count
  attr_reader :data_size

  def initialize(file)
    @file = file
    @data_size = 0
    read_data
  end

  def read_data
    extend_right = @file.read(4).unpack('N')
    @data_size += 4
    extend_top = @file.read(4).unpack('N')
    @data_size += 4
    extend_left = @file.read(4).unpack('N')
    @data_size += 4
    extend_bottom = @file.read(4).unpack('N')
    @data_size += 4

    stitch_time = @file.read(4).unpack('N')
    @data_size += 4

    cursor_thread_change_count = @file.tell
    thread_change_count = @file.read(2).unpack('n').first  # needs to be modified
    @data_size += 2
    puts "There are #{thread_change_count} colors in all designs"

    unknown_c = @file.read(1).unpack('h').first
    @data_size += 1
    abort('Invalid unknown_c') unless unknown_c == 'c'

    cursor_design_block_count = @file.tell
    design_block_count = @file.read(2).unpack('n').first  # needs to be modified
    @data_size += 2
    puts "Designs in this file: #{design_block_count}"
    abort('I can only handle files with one design') unless design_block_count == 1
  end
end

class DesignBlock
  @file = nil

  attr_reader :data_size
  attr_reader :color_block_count
  attr_reader :cursor_bytes_to_end_of_design
  attr_reader :cursor_color_block_count

  def initialize(file)
    @file = file
    @data_size = 0
    read_data
  end

  def read_data
    tag = @file.read(3)
    @data_size += 3
    abort('Invalid DesignBlock tag') unless tag == "\x00\x03\x00"

    cursor_bytes_to_end_of_design = @file.tell
    bytes_to_end_of_design = @file.read(4).unpack('N').first  # needs to be modified
    @data_size += 4
    #puts "Cursor = #{cursor_bytes_to_end_of_design}"
    #puts "Bytes to end of design = #{bytes_to_end_of_design}"

    design_center_x = @file.read(4).unpack('N')
    @data_size += 4
    design_center_y = @file.read(4).unpack('N')
    @data_size += 4

    unknown_000_1 = @file.read(3)
    @data_size += 3
    abort('Invalid unknown_000_1 element') unless unknown_000_1 == "\x00\x00\x00"

    min_half_width = @file.read(4).unpack('N')
    @data_size += 4
    plus_half_width = @file.read(4).unpack('N')
    @data_size += 4
    min_half_heigth = @file.read(4).unpack('N')
    @data_size += 4
    plus_half_heigth = @file.read(4).unpack('N')
    @data_size += 4
    width = @file.read(4).unpack('N')
    @data_size += 4
    height = @file.read(4).unpack('N')
    @data_size += 4

    design_notes_string_length = @file.read(2).unpack('n').first
    @data_size += 2
    design_notes_string = @file.read(design_notes_string_length)
    @data_size += design_notes_string_length

    unknown_dd = @file.read(2)
    @data_size += 2
    abort('Invalid unknown_dd element') unless unknown_dd == 'dd'
    unknown_101 = @file.read(16)
    @data_size += 16
    abort('Invalid unknown_101 element') unless unknown_101 == "\x00\x00\x10\x00" + "\x00\x00\x00\x00" + "\x00\x00\x00\x00" + "\x00\x00\x10\x00"
    unknown_xxpp = @file.read(4)
    @data_size += 4
    abort('Invalid unknown_xxpp element') unless unknown_xxpp == 'xxPP'
    unknown_10 = @file.read(2)
    @data_size += 2
    abort('Invalid unknown_10 element') unless unknown_10 == "\x01\x00"

    production_string_length = @file.read(2).unpack('n').first
    @data_size += 2
    production_string = @file.read(production_string_length)
    @data_size += production_string_length

    cursor_color_block_count = @file.tell
    @color_block_count = @file.read(2).unpack('n').first  # needs to be modified
    @data_size += 2
    puts "This design has #{@color_block_count} colors"
  end
end

class ColorBlocks
  @file = nil
  @color_block_count = 0

  attr_reader :data_size

  def initialize(file, color_block_count)
    @file = file
    @color_block_count = color_block_count
    @data_size = 0
    read_data
  end

  def read_data
    color_block = []
    @color_block_count.times do |color_nr|

      cursor_color_block = @file.tell
      color_block[color_nr] = {:cursor => cursor_color_block}

      puts
      puts "Color \##{color_nr + 1}"

      tag = @file.read(3)
      @data_size += 3
      abort('Invalid ColorBlock tag') unless tag == "\x00\x05\x00"

      bytes_to_next_color_block = @file.read(4).unpack('N').first
      @data_size += 4
      color_block[color_nr][:blocksize] = bytes_to_next_color_block + 7  # 7 = tag + bytes_to_next_color_block
      color_block_data = @file.read(bytes_to_next_color_block)
      @data_size += bytes_to_next_color_block

      # cursor + tag(3) + blocksize(4) + blocksize = next cursor

      color_entries = color_block_data[8].unpack('C').first
      abort("Thread colors is #{color_entries} instead of 1") unless color_entries == 1

      print 'Material: '
      case material = color_block_data[16].unpack('C').first
      when 3
        puts 'Metallic'
      when 4
        puts 'Cotton'
      when 5
        puts 'Rayon'
      when 6
        puts 'Polyester'
      when 10
        puts 'Silk'
      else
        puts 'Unknown material'
      end

      weight = color_block_data[17].unpack('C').first
      puts "Weight: #{weight}"

      catalog_length = color_block_data[18..19].unpack('n').first
      catalog = color_block_data[20, catalog_length]
      puts "Catalog: #{catalog}"

      offset = 20 + catalog_length
      description_length = color_block_data[offset, 2].unpack('n').first
      offset += 2
      description = color_block_data[offset, description_length]
      puts "Description: #{description}"

      offset += description_length
      brand_length = color_block_data[offset, 2].unpack('n').first
      offset += 2
      brand = color_block_data[offset, brand_length]
      puts "Brand: #{brand}"
    end
    #p color_block
  end
end

class VP3split
  @filename_in
  @filename_out
  @file_in
  @file_out
  @header
  @embroidery_summary
  @extend
  @design_block
  @color_blocks

  def initialize(filename_in, filename_out)
    @filename_in = filename_in
    @filename_out = filename_out
  end

  def slurp
    @file_in = File.open(@filename_in, 'rb')
    @header = Header.new(@file_in)
    @embroidery_summary = EmbroiderySummary.new(@file_in)
    @extend = Extend.new(@file_in)
    @design_block = DesignBlock.new(@file_in)
    @color_blocks = ColorBlocks.new(@file_in, @design_block.color_block_count)
    @file_in.close
  end

  def dump
    puts 'DUMP'
  end

end

vp3_split = VP3split.new('test.vp3', 'out.vp3')
vp3_split.slurp
vp3_split.dump

exit


###################################################################################################

######
# cursor_bytes_to_end_of_design
#  4 (bytes_to_end_of_design)
#
#  8 (design_center_x/y)
#  3 (unknown)
# 24 (width/height)
#  2 (design_notes_string_length)
# design_notes_string_length
# 24 (unknown)
#  2 (production_string_length)
# production_string_length
#  2 (color_block_count)
# =========
# 65 + design_notes_string_length + production_string_length
#puts "Expected cursor 1st colorblock = #{cursor_bytes_to_end_of_design + 65 + design_notes_string_length + production_string_length}"

#puts "bytes_to_end_of_design = #{bytes_to_end_of_design}"
total = 65 + design_notes_string_length + production_string_length
color_block.each do |color|
  total += color[:blocksize]
end
#puts "total = #{total}"
abort('Size mismatch') unless total == bytes_to_end_of_design

file.rewind
out = File.open('out.vp3', 'wb')

# test: write colorblock #1

# read/write cursor_bytes_to_end_of_design bytes
preamble = file.read(cursor_bytes_to_end_of_design)
out.write(preamble)
# calculate new bytes_to_end_of_design bytes
# = 65 + design_notes_string_length + production_string_length + color_block[x][:blocksize]
p total = 65 + design_notes_string_length + production_string_length
p color_block
p total += color_block[0][:blocksize]
out.write([total].pack('N'))

old_bytes_to_end = file.read(4)  # skip reading old value
design_block = file.read(63 + design_notes_string_length + production_string_length) # don't read last 2 bytes = #colors
out.write(design_block)

new_nr_colors = 1
out.write([new_nr_colors].pack('n'))

# Move to colorblock
cursor = color_block[0][:cursor]
blocksize = color_block[0][:blocksize]
file.pos = cursor
colorblock = file.read(blocksize)
out.write(colorblock)

# Update bytes_to_eof
new_bytes_to_eof = file.stat.size        # total file size
new_bytes_to_eof -= cursor_bytes_to_eof  # substract bytes before this field
new_bytes_to_eof -= 4                    # substract length of this field itself
# Substract all color blocks
color_block.each do |color|
  new_bytes_to_eof -= color[:blocksize]
end
# Add size of colorblocks
new_bytes_to_eof += color_block[0][:blocksize]
out.pos = cursor_bytes_to_eof
out.write([new_bytes_to_eof].pack('N'))

file.close
out.close
