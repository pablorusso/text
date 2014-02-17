#
#
# Q-gram distance and similarity algorithm implementation, with UTF-8 support.
# The Q-gram is fast way to measure how similar two strings s and t are.
#
#
# Distance
#
# Distance algorithm is specfied in:
#
#  - "Approximate string-matching with q-grams and maximal matches", Esko Ukkonen. 
#    http://www.cs.helsinki.fi/u/ukkonen/TCS92.pdf
# 
# Its calculated as the sum of absolute differences between N-gram vectors 
# of both strings.
#
# eg:
#
#     Text::Qram.distance('abcde','abdcde') # result=3 (using :q_size => 2)
#
#         #a ab bc cd de dc bd  e$
#     V1   1  1  1  1  1  0  0  1
#     V2   1  1  0  1  1  1  1  1
#          ----------------------
#     S    0  0  1  0  0  1  1  0 = 3
#
# where q_size determines ngrams quantity and size. The right value depends 
# mostly on strings and dictionary length, but 2 usually works well.
#
#
# Similarity / Candidate?
#
# Similarity tries to measure how much two strings have in common, it is 
# usually used as a filter before calling a slower edit distance algorithms 
# (eg. Levenshtein), because it executes faster without lossing results:
#     
#     max_distance  = 2
#     is_candidate  = Text::Qram.candidate?(S, T, max_distance)
#     distance      = Text::Levenshtein.distance(S, T, max_distance) if is_candidate
#
# where max_distance is the worst edit distance value tolerated. Qgram  will 
# never discard strings with an edit distance less or equal than max_distance
# but probably will let pass some "false positives" that will be finally discarded
# using Levenshtein algorithm.
# 
# Filters where defined in: 
#
#  - "Approximate String Joins in a Database (Almost) for Free"
#    https://www.cs.umd.edu/class/spring2012/cmsc828L/Papers/GravanoVLDB01.pdf) and in
#  - "Ed-Join: An Efﬁcient Algorithm for Similarity Joins With Edit Distance Constraints"
#    http://www.cse.unsw.edu.au/~weiw/files/VLDB08-EdJoin-Final.pdf
#
#
# Please, note that calculated ngrams are cached when possible to avoid recalculate them when qgram 
# is used to compare the same string multiple times.
#
#
# Author: Pablo Russo (pablorusso@gmail.com)
#
#

module Text

  class Qgram

    # Calculate the qgram distance between two strings +str1+ and +str2+.
    # Calculated as the sum of absolute differences between N-gram vectors 
    # of both strings.
    #
    # The distance is calculated in terms of Unicode codepoints. Be aware that
    # this algorithm does not perform normalisation.
    #
    def self.distance(str1, str2, threshold = nil, q_size = 2, padded = true)
      new.distance(str1, str2, threshold, q_size, padded)
    end

    # Calculate the qgram similarity between two strings +str1+ and +str2+. 
    # It counts how many ngrams are in common between the two strings
    #
    # The similarity is calculated in terms of Unicode codepoints. Be aware that
    # this algorithm does not perform normalisation.
    #
    def self.similarity(str1, str2, threshold = nil, q_size = 2, padded = true)
      new.similarity(str1, str2, threshold, q_size, padded)
    end

    # Returns true if there is a chance that +str1+ and +str2+ are separated by less or equal than +max_distance+, false otherwise
    def self.candidate?(str1, str2, max_distance)
      new.candidate?(str1, str2, max_distance)
    end

    # Return the value as a percentage using on qgrams quantity as divisor
    def self.normalize(str1, str2, value, q_size = 2, padded = true)
      new.normalize(str1, str2, value, q_size, padded)
    end

    # Get a hash containing all the ngrams for +str+
    # Key => ngram
    # Value => how many times appear that ngram in +str+
    def self.mgrams(str, q_size = 2, padded = true)
      new.mgrams(str, q_size, padded)
    end

    # +q_size+ (default 2) Integer > 1 determines ngrams quantity and size. 
    # +padded+ (default 2) True/False  add symbols to increase sensitivity to the symbols at string boundaries (aﬃxing)
    def initialize(q_size = 2, padded = true)
      @q_size = q_size < 1 ? 2 : q_size.round
      @padded = padded
      @cached_anagrams = {}
    end

    # Calculate the qgram distance between two strings +str1+ and +str2+.
    # Calculated as the sum of absolute differences between N-gram vectors 
    # of both strings.
    #
    # The distance is calculated in terms of Unicode codepoints. Be aware that
    # this algorithm does not perform normalisation.
    #
    def distance(str1, str2, threshold = nil, q_size = @q_size, padded = @padded)
      # Arguments validation
      raise Exception.new('Illegal value for q_size: must be at least 1') if q_size < 1
      raise Exception.new('Illegal value for threshold: not a integer greater than 0') if threshold && threshold.class != Fixnum && threshold.to_i <= 0

      # Calculate number of q-grams in strings (plus start and end characters)
      if padded
        num_qgram1 = str1.size+q_size-1
        num_qgram2 = str2.size+q_size-1
      else
        num_qgram1 = [str1.size-(q_size-1),0].max  # Make sure its not negative
        num_qgram2 = [str2.size-(q_size-1),0].max  # Make sure its not negative
      end
      max_common_qgram = [num_qgram1,num_qgram2].min
      threshold = threshold.round.to_i if threshold

      # Check some base cases to go out fast if I can
      return 0 if str1 == str2          # Strings are equal
      return 1 if max_common_qgram <= 1 # Only 1 or 0 ngrams to compare
      
      # Build qgrams
      qgram_list1  = mgrams(str1, q_size, padded)
      qgram_list2  = mgrams(str2, q_size, padded)

      # Count using the shorter q-gram list
      if num_qgram1 < num_qgram2
        short_qgram_list = qgram_list1
        long_qgram_list =  qgram_list2
      else
        short_qgram_list = qgram_list2
        long_qgram_list =  qgram_list1
      end

      # Calculate distance
      distance = 0
      alphabet = (qgram_list1.keys + qgram_list2.keys).uniq
      alphabet.each do |letter|
        str1_result = qgram_list1.has_key?(letter) ? qgram_list1[letter] : 0
        str2_result = qgram_list2.has_key?(letter) ? qgram_list2[letter] : 0
        distance += (str1_result - str2_result).abs
        break if threshold && distance >= threshold.round
      end
      threshold && distance >= threshold.round ? threshold : distance
    end

    # Calculate the qgram similarity between two strings +str1+ and +str2+. 
    # It counts how many ngrams are in common between the two strings
    #
    # The similarity is calculated in terms of Unicode codepoints. Be aware that
    # this algorithm does not perform normalisation.
    #
    def similarity(str1, str2, threshold = nil, q_size = @q_size, padded = @padded)
      # Arguments validation
      raise Exception.new('Illegal value for q_size: must be at least 1') if q_size < 1
      raise Exception.new('Illegal value for threshold: not a integer greater than 0') if threshold && threshold.class != Fixnum && threshold.to_i <= 0

      # Calculate number of q-grams in strings (plus start and end characters)
      if padded
        num_qgram1 = str1.size+q_size-1
        num_qgram2 = str2.size+q_size-1
      else
        num_qgram1 = [str1.size-(q_size-1),0].max  # Make sure its not negative
        num_qgram2 = [str2.size-(q_size-1),0].max  # Make sure its not negative
      end
      max_common_qgram = [num_qgram1,num_qgram2].min
      threshold = threshold.round.to_i if threshold

      # Check some base cases to go out fast if I can
      return max_common_qgram if str1 == str2                 # Strings are equal, all qgrams will be equal
      return 0 if max_common_qgram <= 1                       # Only 1 or 0 ngrams to compare
      return 0 if threshold && threshold > max_common_qgram   # I will never reach threshold
      
      # Build qgrams
      qgram_list1  = mgrams(str1, q_size, padded)
      qgram_list2  = mgrams(str2, q_size, padded)

      # Count using the shorter q-gram list
      if num_qgram1 < num_qgram2
        short_qgram_list = qgram_list1
        long_qgram_list =  qgram_list2
      else
        short_qgram_list = qgram_list2
        long_qgram_list =  qgram_list1
      end

      # Count common ngrams and exit as soon as I reach the threshold
      similarity = 0
      short_qgram_list.keys.each do |q_gram|
        if long_qgram_list.has_key?(q_gram)
          similarity += [short_qgram_list[q_gram], long_qgram_list[q_gram]].min
          break if threshold && similarity >= threshold
        end
      end

      return threshold && similarity >= threshold ? threshold : similarity
    end

    # Returns true if there is a chance that +str1+ and +str2+ are separated by less or equal than +max_distance+, false otherwise
    def candidate?(str1, str2, max_distance)
      raise Exception.new('Illegal value for maximun distance: not an integer greater than 0') if !max_distance || max_distance.class != Fixnum || max_distance.to_i < 0

      if @padded
        threshold = [str1.length, str2.length].max - 1 - (max_distance.round - 1) * @q_size    #If str1 and str2 will  be padded
      else
        threshold =  [str1.length, str2.length].max + 1 - @q_size - max_distance.round*@q_size  #If str1 and str2 won't be padded
      end
      return true if threshold <= 0
      
      similarity = similarity(str1, str2, threshold)
      similarity >= threshold
    end

    # Get a hash containing all the ngrams for +str+. 
    # It cache the ngrams to prevent relcalculations.
    # Key => ngram
    # Value => how many times appear that ngram in +str+
    def mgrams(str, q_size = @q_size, padded = @padded)
      start_char = '#'
      end_char = '$'

      # Add start and end characters (padding)
      if padded && q_size > 1
        qgram_str = start_char * (q_size-1) + str + end_char * (q_size-1)
      else
        qgram_str = str
      end

      # Check cache      
      if @cached_anagrams.has_key?([q_size, qgram_str])
        @cached_anagrams[[q_size, qgram_str]]
      else
        qgram_str.encode(Encoding::UTF_8).unpack("U*").each_cons(q_size).map(&:join).inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
      end
    end

    # Return the distance value as a percentage
    def normalize(str1, str2, value, q_size = @q_size, padded = @padded)
      str1_ngrams  = mgrams(str1, q_size, padded)
      str2_ngrams  = mgrams(str2, q_size, padded)
      total = str1_ngrams.values.inject(0) { |total, item| total += item; total } + str2_ngrams.values.inject(0) { |total, item| total += item; total }
      value / total.to_f
    end
  end
end