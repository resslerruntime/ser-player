// ---------------------------------------------------------------------
// Copyright (C) 2015 Chris Garry
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>
// ---------------------------------------------------------------------


#include "lzw_compressor.h"
#include <QDebug>

#define LOSSY_LZW_SUPPORT 1


// ------------------------------------------
// Constructor
// ------------------------------------------
c_lzw_compressor::c_lzw_compressor(
        uint16_t width,
        uint16_t height,
        uint16_t x_start,
        uint16_t x_end,
        uint16_t y_start,
        uint16_t y_end,
        uint8_t bit_depth,
        uint8_t *p_image_data) :
    m_width(width),
    m_height(height),
    m_x_start(x_start),
    m_x_end(x_end),
    m_y_start(y_start),
    m_y_end(y_end),
    m_bit_depth(bit_depth),
    mp_image_data(p_image_data),
    m_lossy_compression_level(0),
    mp_index_to_index_colour_difference_lut(nullptr),
    m_transparent_index(0)
{
    // Special codes
    m_clear_code = 1 << m_bit_depth;
    m_end_of_information_code = m_clear_code + 1;

    m_next_free_code = m_clear_code + 2;  // Next unused code
    m_code_length = m_bit_depth + 1;  // Current length of codes in bits
    m_current_code = 0xFFFF;

    // Create a new LZW dictonary tree
    mp_lzw_tree.reset(new s_lzw_tree());

    // Reset input position variables
    m_input_x = m_x_start;
    m_input_y = m_y_start;

    // Reset output byte and bit
    m_output_bit = 8;

    // Buffer for compressed data
    mp_compressed_data_buffer.reset(new uint8_t[262]);
}


c_lzw_compressor::~c_lzw_compressor()
{
}


void c_lzw_compressor::set_lossy_details(
        int lossy_compression_level,
        uint8_t *p_index_to_index_colour_difference_lut,
        int transparent_index)
{
    m_lossy_compression_level = lossy_compression_level;
    mp_index_to_index_colour_difference_lut = p_index_to_index_colour_difference_lut;
    m_transparent_index = transparent_index;
}


// ------------------------------------------
// Compress data
// ------------------------------------------
bool c_lzw_compressor::compress_data()
{
    bool complete = (m_input_y > m_y_end) ? true : false;

    if (m_output_bit <= 256 * 8) {
        // No code bits from the previous block needs to be written
        *(mp_compressed_data_buffer.get() + 1) = 0;  // Clear 1st data entry of output buffer
        m_output_bit = 8;  // Reset output bit count
    } else {
        // There is code data from the previous block, copy it to start of buffer
        int bits_from_last_block = m_output_bit - 256 * 8;
        int bytes_from_last_block = (bits_from_last_block + 7) / 8;
        std::copy(mp_compressed_data_buffer.get() + 256,
                  mp_compressed_data_buffer.get() + 256 + bytes_from_last_block,
                  mp_compressed_data_buffer.get() + 1);

        *(mp_compressed_data_buffer.get() + 1 + bytes_from_last_block) = 0;  // Clear next data entry of output buffer
        m_output_bit = 8 + bits_from_last_block;  // Update output bit count
    }

    uint8_t *p_data_ptr = mp_image_data + m_input_y * m_width + m_input_x;

    while ((m_output_bit < 256 * 8) && !complete) {
        uint8_t next_code = *p_data_ptr;

#ifdef LOSSY_LZW_SUPPORT
        // Lossy LZW experimental code - start
        if (/*mp_index_lut != nullptr && */  next_code != m_transparent_index) {
            if (m_current_code != 0xFFFF && mp_lzw_tree->m_current[m_current_code].m_next[next_code] == 0) {
                // Lossy compression code
                bool match_found = false;
                for (int compress_level = 1; compress_level <= (m_lossy_compression_level); compress_level++) {
                    int index = next_code << 8;
                    for (int compare_index = 0; compare_index < (1 << m_bit_depth); compare_index++) {
                        uint8_t colour_diff = mp_index_to_index_colour_difference_lut[index | compare_index];
                        if (colour_diff == compress_level) {
                            if (mp_lzw_tree->m_current[m_current_code].m_next[compare_index] != 0) {
                                next_code = compare_index;
                                *(p_data_ptr) = next_code;
                                match_found = true;
                                break;
                            }
                        }
                    }

                    if (match_found) {
                        break;
                    }
                }
            }
        }
        // Lossy LZW experimental code - end
#endif

        if (m_current_code == 0xFFFF) {
            // First pixel - do nothing but save next_code as current_code
            m_current_code = next_code;
            output_code_to_buffer(m_clear_code, m_code_length, mp_compressed_data_buffer.get());
        } else if (mp_lzw_tree->m_current[m_current_code].m_next[next_code] != 0) {
            // Current run is already in the dictionary tree
            m_current_code = mp_lzw_tree->m_current[m_current_code].m_next[next_code];
        } else { // Finish current run
            // Write current code out
            output_code_to_buffer(m_current_code, m_code_length, mp_compressed_data_buffer.get());

            // Add new run into the dictionary tree
            mp_lzw_tree->m_current[m_current_code].m_next[next_code] = m_next_free_code;

            if(m_next_free_code >= (1ul << m_code_length))
            {
                // The next code needs another bit to represent it
                m_code_length++;
            }

            m_next_free_code++;  // Update to next free code at this one has been written to the dictionary

            if (m_next_free_code == 4096)
            {
                // Dictionary full, delete it and start again
                output_code_to_buffer(m_clear_code, m_code_length, mp_compressed_data_buffer.get());
                mp_lzw_tree.reset(new s_lzw_tree());
                m_code_length = m_bit_depth + 1;
                m_next_free_code = m_clear_code + 2;
            }

            m_current_code = next_code;
        }

        // Move to next pixel to process
        m_input_x++;
        if (m_input_x > m_x_end) {
            m_input_x = m_x_start;
            m_input_y++;
            if (m_input_y > m_y_end) {
                complete = true;
                output_code_to_buffer(m_current_code, m_code_length, mp_compressed_data_buffer.get());  // Output final code
                output_code_to_buffer(m_end_of_information_code, m_code_length, mp_compressed_data_buffer.get());  // Output end of information code
                break;  // Exit loop
            }

            p_data_ptr = mp_image_data + m_input_y * m_width + m_input_x;
        } else {
            p_data_ptr++;
        }
    }

    // Fill in data length byte
    int bytes = ((m_output_bit + 7) / 8) - 1;
    if (bytes > 255) {
        bytes = 255;
        complete = false;  // Cannot be complete if more than 255 bytes have been accumulated
    }

    mp_compressed_data_buffer[0] = bytes;  // Write byte count to start of buffer
    return complete;
}


// ------------------------------------------
// Output code to output buffer
// ------------------------------------------
void c_lzw_compressor::output_code_to_buffer(
        uint32_t code,
        uint32_t code_length,
        uint8_t *p_output_buffer)
{
    union u_bit_shifter
    {
        uint8_t uint8[4];
        uint32_t uint32;
    };

    u_bit_shifter bit_shifter;
    int output_byte_number = m_output_bit / 8;
    bit_shifter.uint32 = code << (m_output_bit % 8);
    *(p_output_buffer + output_byte_number + 0) |= bit_shifter.uint8[0];
    *(p_output_buffer + output_byte_number + 1) = bit_shifter.uint8[1];
    *(p_output_buffer + output_byte_number + 2) = bit_shifter.uint8[2];
    m_output_bit += code_length;  // Update output bit tracking variable
}
