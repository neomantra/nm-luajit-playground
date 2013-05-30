--[[
Copyright (c) 2012-2013 neomantra LLC.
Author: Evan Wies <evan@neomantra.net>

Released under the MIT License.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

USAGE
=====
local ring_buffer = require 'ring_buffer'
local ring = ring_buffer.new( 1024 )

ring:data()      returns the uint8_t* of the data at the ring's current position 
ring:data_left()

ring:tail()
ring:buffer_left

ring:buffer()       returns the uint8_t* to the underlying buffer
ring:buffer_size()  returns the total size of the ring's buffer
ring:head_offset()  returns the byte offset of the ring's current position
ring:tail_offset()  returns the byte offset of the ring's current position

ring:size_left() returns the number of bytes available from the ring's current position

ring:pull(n) advance the buffer's head position by 'n' bytes, returns pointer to the new head
ring:push(n) advance the buffer's tail position by 'n' bytes, returns pointer to the new tail

ring:rotate()   move the head to the front of the buffercurrent position to the start of the underlying buffer
--]]

local ffi = require 'ffi'

-- public API
local ring_buffer = {}


-- statistics
local ring_buffer_count = 0
local ring_buffer_total = 0


ffi.cdef([[
struct ring_buffer {
    size_t      size_;      // size of buffer
    size_t      head_;      // offset of current head
    size_t      tail_;      // offset of current tail
    uint8_t     buffer_[?]; // where data is stored
};
]])

local ring_buffer_mt = {
    __index = {
        data = function(rb) return rb.buffer_ + rb.head_ end,
        data_size = function(rb) return rb.tail_ - rb.head_ end,
        data_left = function(rb) return rb.tail_ - rb.head_ end,

        tail = function(rb) return rb.buffer_ + rb.tail_ end,
        buffer_left = function(rb) return rb.size_ - rb.tail_ end,
 
        clear = function(rb) rb.head_, rb.tail_ = 0, 0 end,

        -- moves the tail forward by 'bytes' and returns the new tail*
        push = function(rb, bytes)
            local size_left = rb.size_ - rb.tail_
            if bytes > size_left then return nil, 'pushed beyond end' end
            rb.tail_ = rb.tail_ + bytes
            return rb.buffer_ + rb.tail_
        end,

        -- moves the head forward by 'bytes and returns the new head*
        pull = function(rb, bytes)
            local data_left = rb.tail_ - rb.head_
            if bytes > data_left then return nil, 'pulled beyond tail' end
            
            rb.head_ = rb.head_ + bytes
            return rb.buffer_ + rb.head_
        end,
            
        rotate = function(rb)
            local data_size = rb.tail_ - rb.head_
            ffi.copy( rb.buffer_, rb.buffer_ + rb.head_, data_size )
            rb.head_, rb.tail_ = 0, data_size
        end,        
     },

    __gc = function(rb)
        -- update stats
        ring_buffer_count = ring_buffer_count - 1
        ring_buffer_total = ring_buffer_total - rb.size_
    end
}

local ring_buffer_t = ffi.metatype("struct ring_buffer", ring_buffer_mt)


function ring_buffer.new( size )
    local rb = ring_buffer_t( size, size, 0, 0 )   -- VLA, size, head, tail
    if not rb then error("ring_buffer.new   buffer allocation failed" ) end
    ring_buffer_count = ring_buffer_count + 1
    ring_buffer_total = ring_buffer_total + size
    return rb
end


function ring_buffer.stats()
    return ring_buffer_count, ring_buffer_total
end

-- return public API
return ring_buffer

