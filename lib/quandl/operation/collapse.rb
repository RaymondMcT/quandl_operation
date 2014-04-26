# subclasses
require 'quandl/operation/collapse/guess'
# collapse
module Quandl
module Operation

class Collapse

  class << self
  
    def perform(data, type)
      type = {:freq => type} if type.class != Hash
      assert_valid_arguments!(data, type)
      # nothing to do with an empty array
      return data unless data.compact.present?
      # source order
      order = Sort.order?(data)
      # operations expect data in ascending order
      data = Sort.asc(data)
      # collapse
      data = collapse(data, type[:freq], type[:algo])
      # return to original order
      data = Sort.desc(data) if order == :desc
      # onwards
      data
    end
    
    def assert_valid_arguments!(data, type)
      raise ArgumentError, "data must be an Array. Received: #{data.class}" unless data.is_a?(Array)
      raise ArgumentError, "frequency must be one of #{valid_collapses}. Received: #{type[:freq]}" unless valid?(type[:freq])
      raise ArgumentError, "algorithm must be one of #{valid_collapse_algos}. Received: #{type[:algo]}" unless type[:algo].nil? || valid_collapse_algo?(type[:algo])
    end
    
    def valid_collapse?(type)
      valid?(type)
    end
    
    def valid?(type)
      valid_collapses.include?( type.try(:to_sym) )
    end
    
    def valid_collapses
      [ :daily, :weekly, :monthly, :quarterly, :annual ]
    end

    def valid_collapse_algos
      [ :min, :max, :first, :last, :mid, :sum, :avg, :median ]
    end

    def valid_collapse_algo?(type)
      valid_collapse_algos.include?( type.try(:to_sym) )
    end

  
    def collapse(data, frequency, algorithm)
      algorithm ||= :last
      return data unless valid_collapse?( frequency )
      return data unless valid_collapse_algo?( algorithm )
      # store the new collapsed data
      collapsed_data = {}
      data_in_range = {}
      
      case algorithm.to_sym
      when :min
        range = get_range( data[0][0], frequency )
        data.each do |row|
          date, value = row[0], row[1..-1]
          range = get_range(date, frequency) unless inside_range?(date, range)
          collapsed_data[range] ||= value
          value.each_index do |a|
            collapsed_data[range][a] = value[a] if (collapsed_data[range][a].nil?  && !value[a].nil?) || collapsed_data[range][a] > value[a]
          end
        end
        return(to_table(collapsed_data))
      end

      when :max
        range = get_range( data[0][0], frequency )
        data.each do |row|
          date, value = row[0], row[1..-1]
          range = get_range(date, frequency) unless inside_range?(date, range)
          collapsed_data[range] ||= value
          value.each_index do |a|
            collapsed_data[range][a] = value[a] if (collapsed_data[range][a].nil?  && !value[a].nil?) || collapsed_data[range][a] < value[a]
          end
        end
        return(to_table(collapsed_data))
      when :first
        range = get_range( data[-1][0], frequency )
        Sort.desc(data).each do |row|
          # grab date and values
          date, value = row[0], row[1..-1]
          value = value.first if value.count == 1
          # bump to the next range if it exceeds the current one
          range = get_range(date, frequency) unless inside_range?(date, range)
          # consider the value for the next range
          if inside_range?(date, range) && value.present?
            # merge this and previous row if nils are present
            value = merge_row_values( value, collapsed_data[range] ) unless collapsed_data[range].nil?
            # assign value
            collapsed_data[range] = value
          end
        end
        return(to_table(collapsed_data))
      when :last
        range = find_end_of_range( data[0][0], frequency )
        data.each do |row|
          # grab date and values
          date, value = row[0], row[1..-1]
          value = value.first if value.count == 1
          # bump to the next range if it exceeds the current one
          range = find_end_of_range(date, frequency) unless inside_range?(date, range)
          # consider the value for the next range
          if inside_range?(date, range) && value.present?
            # merge this and previous row if nils are present
            value = merge_row_values( value, collapsed_data[range] ) unless collapsed_data[range].nil?
            # assign value
            collapsed_data[range] = value
          end
        end
        return(to_table(collapsed_data))
      when :mid
      when :sum
        range = get_range( data[0][0], frequency )
        data.each do |row|
          date, value = row[0], row[1..-1]
          range = get_range(date, frequency) unless inside_range?(date, range)
          data_in_range[range] ||= []
          data_in_range[range] << value
        end
        data_in_range.each do |range, values|
          sum = Array.new(values.first.length, 0)
          values.each do |value|
            value.each_index do |index|
              sum[index] += value[index] unless value[index].nil?
            end
          end
          collapsed_data[range] = sum
        end
        return(to_table(collapsed_data))
      when :avg
        range = get_range( data[0][0], frequency )
        data.each do |row|
          date, value = row[0], row[1..-1]
          range = get_range(date, frequency) unless inside_range?(date, range)
          data_in_range[range] ||= []
          data_in_range[range] << value
        end
        data_in_range.each do |range, values|
          avg = Array.new(values.first.length, 0)
          counter = Array.new(values.first.length, 0)
          values.each do |value|
            value.each_index do |index|
              avg[index] += value[index] unless value[index].nil?
              counter[index] += 1 unless value[index].nil?
            end
          end
          avg.each_index do |index|
            avg[index] = counter[index] == 0 ? nil : avg[index]/counter[index]
          end
          collapsed_data[range] = avg
        end
        return(to_table(collapsed_data))
      when :median
        # data_in_range.each do |range, values|
        #   avg = Array.new(values.first.length, 0)
        #   counter = Array.new(values.first.length, 0)
        #   values.each do |value|
        #     value.each_index do |index|
        #       avg[index] += value[index] unless value[index].nil?
        #       counter[index] += 1 unless value[index].nil?
        #     end
        #   end
        #   avg.each_index do |index|
        #     avg[index] = counter[index] == 0 ? nil : avg[index]/counter[index]
        #   end
        #   collapsed_data[range] = avg
        # end
        # return(to_table(collapsed_data))

      # iterate over the data
      
    end
    
    def to_table(data)
      data.collect do |date, values|
        date = date[1] if date.is_a?(Array)
        if values.is_a?(Array)
          values.unshift(date)
        else
          [date, values]
        end
      end
    end
    
    def merge_row_values(top_row, bottom_row)
      # merge previous values when nils are present
      if top_row.is_a?(Array) && top_row.include?(nil)
        # find nil indexes
        indexes = find_each_index(top_row, nil)
        # merge nils with previous values
        indexes.each{|index| top_row[index] = bottom_row[index] }
      end
      top_row
    end
    
    def collapses_greater_than(freq)
      return [] unless freq.respond_to?(:to_sym)
      index = valid_collapses.index(freq.to_sym)
      index.present? ? valid_collapses.slice( index + 1, valid_collapses.count ) : []
    end
    
    def collapses_greater_than_or_equal_to(freq)
      return [] unless freq.respond_to?(:to_sym)
      valid_collapses.slice( valid_collapses.index(freq.to_sym), valid_collapses.count )
    end
    
    def frequency?(data)
      Guess.frequency(data)
    end
  
    def inside_range?(date, range)
      if range.is_a?(Array)
        range[0] <= date && date <= range[1]
      else
        date <= range
      end
    end

    def get_range(date, frequency)
      [date.start_of_frequency(frequency), date.end_of_frequency(frequency)]
    end
  
    def find_end_of_range(date, frequency)
      date.end_of_frequency(frequency)
    end

    def find_start_of_range(date, frequency)
      date.start_of_frequency(frequency)
    end
  
    def find_each_index(array, find)
      found, index, q = -1, -1, []
      while found
        found = array[index+1..-1].index(find)
        if found
          index = index + found + 1
          q << index
        end
      end
      q
    end
  
  end

end
end
end