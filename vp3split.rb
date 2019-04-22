#!/usr/bin/env ruby

module Vp3BinaryFileData

  def read_data_bytes(nr)
    @data_size += nr
    return @file.read(nr)
  end

  def carbon_copy(block)
    @file_in.pos = block.cursor_start
    @file_out.write(@file_in.read(block.data_size))
  end

end

class Header
  include Vp3BinaryFileData

  attr_reader :cursor_start
  attr_reader :data_size

  def initialize(file)
    @file = file
    @data_size = 0
    @cursor_start = @file.tell
  end

  def read_data
    magic_string = read_data_bytes(6)
    abort('Invalid magic_string') unless magic_string == "%vsm%\x00"

    production_string_length = read_data_bytes(2).unpack('n').first
    production_string = read_data_bytes(production_string_length)
  end
end

class EmbroiderySummary
  include Vp3BinaryFileData

  attr_reader :cursor_start
  attr_reader :data_size
  attr_reader :cursor_bytes_to_eof

  def initialize(file)
    @file = file
    @data_size = 0
    @cursor_start = @file.tell
  end

  def read_data
    tag = read_data_bytes(3)
    abort('Invalid EmbroiderySummary tag') unless tag == "\x00\x02\x00"

    cursor_bytes_to_eof = @file.tell
    bytes_to_eof = read_data_bytes(4).unpack('N').first   # needs to be modified

    settings_string_length = read_data_bytes(2).unpack('n').first
    settings_string = read_data_bytes(settings_string_length)
  end
end

class Extend
  include Vp3BinaryFileData

  attr_reader :cursor_start
  attr_reader :data_size
  attr_reader :cursor_stitch_count
  attr_reader :cursor_thread_change_count

  def initialize(file)
    @file = file
    @data_size = 0
    @cursor_start = @file.tell
  end

  def read_data
    extend_right = read_data_bytes(4).unpack('N')
    extend_top = read_data_bytes(4).unpack('N')
    extend_left = read_data_bytes(4).unpack('N')
    extend_bottom = read_data_bytes(4).unpack('N')

    cursor_stitch_count = @file.tell
    stitch_count = read_data_bytes(4).unpack('N').first  # needs to be modified
    puts "There are #{stitch_count} stitches in total"

    cursor_thread_change_count = @file.tell
    thread_change_count = read_data_bytes(2).unpack('n').first  # needs to be modified
    puts "There are #{thread_change_count} colors in total"

    unknown_c = read_data_bytes(1).unpack('h').first
    abort('Invalid unknown_c') unless unknown_c == 'c'

    design_block_count = read_data_bytes(2).unpack('n').first
    #puts "Designs in this file: #{design_block_count}"
    abort('I can only handle files with one design') unless design_block_count == 1
  end
end

class DesignBlock
  include Vp3BinaryFileData

  attr_reader :cursor_start
  attr_reader :data_size
  attr_reader :color_block_count
  attr_reader :cursor_bytes_to_end_of_design
  attr_reader :cursor_color_block_count

  def initialize(file)
    @file = file
    @data_size = 0
    @cursor_start = @file.tell
  end

  def read_data
    tag = read_data_bytes(3)
    abort('Invalid DesignBlock tag') unless tag == "\x00\x03\x00"

    cursor_bytes_to_end_of_design = @file.tell
    bytes_to_end_of_design = read_data_bytes(4).unpack('N').first  # needs to be modified
    #puts "Cursor = #{cursor_bytes_to_end_of_design}"
    #puts "Bytes to end of design = #{bytes_to_end_of_design}"

    design_center_x = read_data_bytes(4).unpack('N')
    design_center_y = read_data_bytes(4).unpack('N')

    unknown_000_1 = read_data_bytes(3)
    abort('Invalid unknown_000_1 element') unless unknown_000_1 == "\x00\x00\x00"

    min_half_width = read_data_bytes(4).unpack('N')
    plus_half_width = read_data_bytes(4).unpack('N')
    min_half_heigth = read_data_bytes(4).unpack('N')
    plus_half_heigth = read_data_bytes(4).unpack('N')
    width = read_data_bytes(4).unpack('N')
    height = read_data_bytes(4).unpack('N')

    design_notes_string_length = read_data_bytes(2).unpack('n').first
    design_notes_string = read_data_bytes(design_notes_string_length)

    unknown_dd = read_data_bytes(2)
    abort('Invalid unknown_dd element') unless unknown_dd == 'dd'
    unknown_101 = read_data_bytes(16)
    abort('Invalid unknown_101 element') unless unknown_101 == "\x00\x00\x10\x00" + "\x00\x00\x00\x00" + "\x00\x00\x00\x00" + "\x00\x00\x10\x00"
    unknown_xxpp = read_data_bytes(4)
    abort('Invalid unknown_xxpp element') unless unknown_xxpp == 'xxPP'
    unknown_10 = read_data_bytes(2)
    abort('Invalid unknown_10 element') unless unknown_10 == "\x01\x00"

    production_string_length = read_data_bytes(2).unpack('n').first
    production_string = read_data_bytes(production_string_length)

    cursor_color_block_count = @file.tell
    @color_block_count = read_data_bytes(2).unpack('n').first  # needs to be modified
    puts "This design has #{@color_block_count} colors"
  end
end

class ColorBlocks
  include Vp3BinaryFileData

  attr_reader :cursor_start
  attr_reader :data_size

  def initialize(file, color_block_count)
    @file = file
    @color_block_count = color_block_count
    @data_size = 0
    @cursor_start = @file.tell
  end

  def read_data
    color_block = []
    @color_block_count.times do |color_nr|

      cursor_color_block = @file.tell
      color_block[color_nr] = {:cursor => cursor_color_block}

      tag = read_data_bytes(3)
      abort('Invalid ColorBlock tag') unless tag == "\x00\x05\x00"

      bytes_to_next_color_block = read_data_bytes(4).unpack('N').first
      color_block[color_nr][:blocksize] = bytes_to_next_color_block + 7  # 7 = tag + bytes_to_next_color_block
      color_block_data = read_data_bytes(bytes_to_next_color_block)

      # cursor + tag(3) + blocksize(4) + blocksize = next cursor

      color_entries = color_block_data[8].unpack('C').first
      abort("Thread colors is #{color_entries} instead of 1") unless color_entries == 1

      case material = color_block_data[16].unpack('C').first
      when 3
        color_block[color_nr][:material] = 'Metallic'
      when 4
        color_block[color_nr][:material] = 'Cotton'
      when 5
        color_block[color_nr][:material] = 'Rayon'
      when 6
        color_block[color_nr][:material] = 'Polyester'
      when 10
        color_block[color_nr][:material] = 'Silk'
      else
        color_block[color_nr][:material] = 'Unknown material'
      end

      color_block[color_nr][:weight] = color_block_data[17].unpack('C').first

      catalog_length = color_block_data[18..19].unpack('n').first
      color_block[color_nr][:catalog] = color_block_data[20, catalog_length]

      offset = 20 + catalog_length
      description_length = color_block_data[offset, 2].unpack('n').first
      offset += 2
      color_block[color_nr][:description] = color_block_data[offset, description_length]

      offset += description_length
      brand_length = color_block_data[offset, 2].unpack('n').first
      offset += 2
      color_block[color_nr][:brand] = color_block_data[offset, brand_length]
      offset += brand_length

      displacement_x = color_block_data[offset, 4].unpack('N')
      offset += 4
      displacement_y = color_block_data[offset, 4].unpack('N')
      offset += 4

      stitch_data_tag = color_block_data[offset, 3]
      offset += 3
      abort('Invalid StitchData tag') unless stitch_data_tag == "\x00\x01\x00"

      stitch_data_length = color_block_data[offset, 4].unpack('N').first
      offset += 4

      stitch_data = color_block_data[offset, stitch_data_length]
    end

    @color_block_count.times do |color_nr|
      print "#{color_nr} - "
      print "#{color_block[color_nr][:material]} - "
      print "#{color_block[color_nr][:weight]} - "
      print "#{color_block[color_nr][:catalog]} - "
      print "#{color_block[color_nr][:description]} - "
      print "#{color_block[color_nr][:brand]} - "
      puts
    end

  end


end

class Slurp
  include Vp3BinaryFileData

  attr_reader :header
  attr_reader :embroidery_summary
  attr_reader :extend
  attr_reader :design_block
  attr_reader :color_blocks

  def initialize(file_in)
    @file_in = file_in
  end

  def read_header
    @header = Header.new(@file_in)
    @header.read_data
  end

  def read_embroidery_summary
    @embroidery_summary = EmbroiderySummary.new(@file_in)
    @embroidery_summary.read_data
  end

  def read_extend
    @extend = Extend.new(@file_in)
    @extend.read_data
  end

  def read_design_block
    @design_block = DesignBlock.new(@file_in)
    @design_block.read_data
  end

  def read_color_blocks
    @color_blocks = ColorBlocks.new(@file_in, @design_block.color_block_count)
    @color_blocks.read_data
  end

end

class Dump
  include Vp3BinaryFileData

  attr_reader :slurp

  def initialize(file_in, file_out, slurp)
    @file_in = file_in
    @file_out = file_out
    @slurp = slurp
  end

  def write_header
    carbon_copy(@slurp.header)
  end

  def write_embroidery_summary
    carbon_copy(@slurp.embroidery_summary)
    # TODO New bytes_to_eof needs to be calculated and written
  end

  def write_extend
    carbon_copy(@slurp.extend)
    # TODO New stitch_count needs to be calculated and written
    # TODO New thread_change_count needs to be written
  end

  def write_design_block
    carbon_copy(@slurp.design_block)
    # TODO New bytes_to_end_of_design needs to be calculated and written
    # TODO New color_block_count needs to be written
  end

  def write_color_blocks
    carbon_copy(@slurp.color_blocks)
    # TODO Only write some color_blocks
  end

end

class VP3split
  include Vp3BinaryFileData

  def initialize(filename_in, filename_out)
    @filename_in = filename_in
    @filename_out = filename_out
  end

  def open_files
    @file_in = File.open(@filename_in, 'rb')
    @file_out = File.open(@filename_out, 'wb')
  end

  def close_files
    @file_in.close
    @file_out.close
  end

  def slurp
    @slurp = Slurp.new(@file_in)
    @slurp.read_header
    @slurp.read_embroidery_summary
    @slurp.read_extend
    @slurp.read_design_block
    @slurp.read_color_blocks
  end

  def dump
    @dump = Dump.new(@file_in, @file_out, @slurp)
    @dump.write_header
    @dump.write_embroidery_summary
    @dump.write_extend
    @dump.write_design_block
    @dump.write_color_blocks
  end

end

vp3_split = VP3split.new('test.vp3', 'out.vp3')
vp3_split.open_files
vp3_split.slurp
vp3_split.dump
vp3_split.close_files

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
