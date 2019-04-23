#!/usr/bin/env ruby

module Vp3BinaryFileData

  def read_data_bytes(nr)
    @data_size += nr
    return @file.read(nr)
  end

  def carbon_copy(cursor, size)
    @file_in.pos = cursor
    @file_out.write(@file_in.read(size))
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

    @cursor_bytes_to_eof = @file.tell
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

    @cursor_stitch_count = @file.tell
    stitch_count = read_data_bytes(4).unpack('N').first  # needs to be modified
    puts "There are #{stitch_count} stitches in total"

    @cursor_thread_change_count = @file.tell
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

    @cursor_bytes_to_end_of_design = @file.tell
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

    @cursor_color_block_count = @file.tell
    @color_block_count = read_data_bytes(2).unpack('n').first  # needs to be modified
    puts "This design has #{@color_block_count} colors"
  end
end

class ColorBlocks
  include Vp3BinaryFileData

  attr_reader :cursor_start
  attr_reader :data_size
  attr_reader :color_blocks

  def initialize(file, color_block_count)
    @file = file
    @color_block_count = color_block_count
    @data_size = 0
    @cursor_start = @file.tell
  end

  def read_data
    @color_blocks = []
    @color_block_count.times do |color_nr|

      cursor_color_block = @file.tell
      @color_blocks[color_nr] = {:cursor => cursor_color_block}

      tag = read_data_bytes(3)
      abort('Invalid ColorBlock tag') unless tag == "\x00\x05\x00"

      bytes_to_next_color_block = read_data_bytes(4).unpack('N').first
      @color_blocks[color_nr][:blocksize] = bytes_to_next_color_block + 7  # 7 = tag + bytes_to_next_color_block
      color_block_data = read_data_bytes(bytes_to_next_color_block)

      # cursor + tag(3) + blocksize(4) + blocksize = next cursor

      color_entries = color_block_data[8].unpack('C').first
      abort("Thread colors is #{color_entries} instead of 1") unless color_entries == 1

      case material = color_block_data[16].unpack('C').first
      when 3
        @color_blocks[color_nr][:material] = 'Metallic'
      when 4
        @color_blocks[color_nr][:material] = 'Cotton'
      when 5
        @color_blocks[color_nr][:material] = 'Rayon'
      when 6
        @color_blocks[color_nr][:material] = 'Polyester'
      when 10
        @color_blocks[color_nr][:material] = 'Silk'
      else
        @color_blocks[color_nr][:material] = 'Unknown material'
      end

      @color_blocks[color_nr][:weight] = color_block_data[17].unpack('C').first

      catalog_length = color_block_data[18..19].unpack('n').first
      @color_blocks[color_nr][:catalog] = color_block_data[20, catalog_length]

      offset = 20 + catalog_length
      description_length = color_block_data[offset, 2].unpack('n').first
      offset += 2
      @color_blocks[color_nr][:description] = color_block_data[offset, description_length]

      offset += description_length
      brand_length = color_block_data[offset, 2].unpack('n').first
      offset += 2
      @color_blocks[color_nr][:brand] = color_block_data[offset, brand_length]
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
      @color_blocks[color_nr][:stitch_data_length] = stitch_data_length - 3  # exclude StitchStart tag

      stitch_data = color_block_data[offset, stitch_data_length]
      @color_blocks[color_nr][:nr_stitches] = analyze_stitches(stitch_data.unpack("C*"))
    end

    return @color_blocks
  end

  def analyze_stitches stitch_data
    offset = 0
    stitch_start = stitch_data[offset, 3]
    offset += 3
    abort('Invalid StitchStart') unless stitch_start == [0x0a, 0xf6, 0x00]

    # stitch_data starts with 3 bytes StitchStart tag
    # rest is stitches
    total_bytes_to_read = stitch_data.length

    nr_80_01 = 0
    nr_80_02 = 0
    nr_80_03 = 0

    nr_stitches = 0
    read_stitches = true
    long_form = false
    while read_stitches
      byte1 = stitch_data[offset, 1].first
      byte2 = stitch_data[offset + 1, 1].first
      if byte1 == 0x80
        # escape
        if byte2 == 0x01
          # enable long form
          long_form = true
          nr_stitches += 1
          nr_80_01 += 1
          offset += 6  # skip 2 bytes escape (80 01) + 2 bytes dx + 2 bytes dy
        elsif byte2 == 0x02
          # disable long form
          long_form = false
          nr_80_02 += 1
          offset += 2
        elsif byte2 == 0x03
          # deleted/null/end stitch
          nr_80_03 += 1
          offset += 2
          #printf("%.2X %.2X\n", byte1, byte2)
        end
      else
        # normal dx,xy
        #printf("%.2X %.2X\n", byte1, byte2)
        nr_stitches += 1
        offset += 2  # 1 byte dx + 1 byte dy
      end
      if total_bytes_to_read - offset < 2
        read_stitches = false
      end

    end
    #puts "Number of stitches = #{nr_stitches}"
    #puts "#{nr_80_01}-#{nr_80_02}-#{nr_80_03}"
    return nr_stitches
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
    blocks = ColorBlocks.new(@file_in, @design_block.color_block_count)
    @color_blocks = blocks.read_data
    total_stitches = 0
    color_blocks.each_with_index do |color, i|
      print "Color \##{i + 1} - "
      print "#{color[:material]} - "
      print "#{color[:weight]} - "
      print "#{color[:catalog]} - "
      print "#{color[:description]} - "
      print "#{color[:brand]} - "
      print "~#{color[:stitch_data_length] / 2} - "
      puts "#{color[:nr_stitches]} stitches"
      total_stitches += color[:nr_stitches]
    end
    puts "Total stitches analyzed = #{total_stitches}"

  end

end

class Dump
  include Vp3BinaryFileData

  attr_reader :slurp

  def initialize(file_in, file_out, slurp, colorblocks_to_dump)
    @file_in = file_in
    @file_out = file_out
    @slurp = slurp
    @colorblocks_to_dump = colorblocks_to_dump
  end

  def calculate
    @extend_stitch_count = 0
    @extend_thread_change_count = 0
    @designblock_color_count = 0

    @embroiderysummary_bytes_to_eof = 0
    @embroiderysummary_bytes_to_eof += @slurp.extend.data_size
    @embroiderysummary_bytes_to_eof += @slurp.design_block.data_size
    @embroiderysummary_bytes_to_eof += 2

    @designblock_bytes_to_end_of_design = 0
    @designblock_bytes_to_end_of_design += @slurp.design_block.data_size
    @designblock_bytes_to_end_of_design -= 7

    @slurp.color_blocks.each_with_index do |color, nr|
      if @colorblocks_to_dump.include?(nr + 1)
        @embroiderysummary_bytes_to_eof += color[:blocksize]
        @designblock_bytes_to_end_of_design += color[:blocksize]
        @extend_stitch_count += color[:nr_stitches]
        @extend_thread_change_count += 1
        @designblock_color_count +=1
      end
    end

    puts
    puts "Calculated for colors #{@colorblocks_to_dump}:"
    puts "EmbroiderySummary bytes_to_eof = #{@embroiderysummary_bytes_to_eof}"
    puts "Extend stitch_count = #{@extend_stitch_count}"
    puts "Extend thread_change_count = #{@extend_thread_change_count}"
    puts "DesignBlock bytes_to_end_of_design = #{@designblock_bytes_to_end_of_design}"
    puts "DesignBlock color_count = #{@designblock_color_count}"
  end

  def modify position, value, format
    puts "Modify at #{position} = #{value}"
    eof_pos = @file_out.tell
    @file_out.pos = position
    @file_out.write([value].pack(format))
    @file_out.pos = eof_pos
  end

  def write_header
    carbon_copy(@slurp.header.cursor_start, @slurp.header.data_size)
  end

  def write_embroidery_summary
    carbon_copy(@slurp.embroidery_summary.cursor_start, @slurp.embroidery_summary.data_size)
    modify @slurp.embroidery_summary.cursor_bytes_to_eof, @embroiderysummary_bytes_to_eof, "N"
  end

  def write_extend
    carbon_copy(@slurp.extend.cursor_start, @slurp.extend.data_size)
    modify @slurp.extend.cursor_stitch_count, @extend_stitch_count, "N"
    modify @slurp.extend.cursor_thread_change_count, @extend_thread_change_count, "n"
  end

  def write_design_block
    carbon_copy(@slurp.design_block.cursor_start, @slurp.design_block.data_size)
    modify @slurp.design_block.cursor_bytes_to_end_of_design, @designblock_bytes_to_end_of_design, "N"
    modify @slurp.design_block.cursor_color_block_count, @designblock_color_count, "n"
  end

  def write_color_blocks
    @slurp.color_blocks.each_with_index do |color, nr|
      if @colorblocks_to_dump.include?(nr + 1)
        carbon_copy(color[:cursor], color[:blocksize])
      end
    end
  end

end

class VP3split
  include Vp3BinaryFileData

  def initialize filename_in
    @filename_in = filename_in
    @file_in = File.open(@filename_in + '.vp3', 'rb')
  end

  def deinit
    @file_in.close
  end

  def slurp
    @slurp = Slurp.new(@file_in)
    @slurp.read_header
    @slurp.read_embroidery_summary
    @slurp.read_extend
    @slurp.read_design_block
    @slurp.read_color_blocks
  end

  def dump(colors_to_dump, name_extra)
    @file_out = File.open(@filename_in + name_extra + '.vp3', 'wb')
    @dump = Dump.new(@file_in, @file_out, @slurp, colors_to_dump)
    @dump.calculate
    @dump.write_header
    @dump.write_embroidery_summary
    @dump.write_extend
    @dump.write_design_block
    @dump.write_color_blocks
    @file_out.close
  end

end

vp3_split = VP3split.new'essie'
vp3_split.slurp
vp3_split.dump((1..10).to_a, '-01')
vp3_split.dump((11..20).to_a, '-02')
vp3_split.deinit
