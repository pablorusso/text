require_relative "./test_helper"
require "text/qgram"

class QgramTest < Test::Unit::TestCase
  def iso_8859_1(s)
    s.force_encoding(Encoding::ISO_8859_1)
  end

  def test_should_treat_utf_8_codepoints_as_one_element
    assert_equal 4, Text::Qgram.distance("föo", "foo")
    assert_equal 4, Text::Qgram.distance("français", "francais")
    assert_equal 4, Text::Qgram.distance("français", "franæais")
    assert_equal 5, Text::Qgram.distance("私の名前はポールです", "ぼくの名前はポールです")
    assert_equal 2, Text::Qgram.similarity("föo", "foo")
    assert_equal 7, Text::Qgram.similarity("français", "francais")
    assert_equal 7, Text::Qgram.similarity("français", "franæais")
    assert_equal 9, Text::Qgram.similarity("私の名前はポールです", "ぼくの名前はポールです")
  end

  def test_should_process_single_byte_encodings
    assert_equal 4, Text::Qgram.distance(iso_8859_1("f\xF6o"), iso_8859_1("foo"))
    assert_equal 4, Text::Qgram.distance(iso_8859_1("fran\xE7ais"), iso_8859_1("francais"))
    assert_equal 4, Text::Qgram.distance(iso_8859_1("fran\xE7ais"), iso_8859_1("fran\xE6ais"))
    assert_equal 0, Text::Qgram.distance(iso_8859_1("fran\xE7ais"), iso_8859_1("fran\xE7ais"))
    assert_equal 2, Text::Qgram.similarity(iso_8859_1("f\xF6o"), iso_8859_1("foo"))
    assert_equal 7, Text::Qgram.similarity(iso_8859_1("fran\xE7ais"), iso_8859_1("francais"))
    assert_equal 7, Text::Qgram.similarity(iso_8859_1("fran\xE7ais"), iso_8859_1("fran\xE6ais"))
    assert_equal 9, Text::Qgram.similarity(iso_8859_1("fran\xE7ais"), iso_8859_1("fran\xE7ais"))
  end

  def test_distance
    word = "Healed"
    assert_equal 4, Text::Qgram.distance(word, "Sealed")
    assert_equal 7, Text::Qgram.distance(word, "Healthy")
    assert_equal 5, Text::Qgram.distance(word, "Heard")
    assert_equal 6, Text::Qgram.distance(word, "Herded")
    assert_equal 8, Text::Qgram.distance(word, "Help")
    assert_equal 10, Text::Qgram.distance(word, "Solded")
    assert_equal 10, Text::Qgram.distance(word, "Sold")
    assert_equal 14, Text::Qgram.distance(word, "Solder")
  end

  def test_similarity
    word = "Healed"
    assert_equal 5, Text::Qgram.similarity(word, "Sealed")
    assert_equal 4, Text::Qgram.similarity(word, "Healthy")
    assert_equal 4, Text::Qgram.similarity(word, "Heard")
    assert_equal 4, Text::Qgram.similarity(word, "Herded")
    assert_equal 2, Text::Qgram.similarity(word, "Help")
    assert_equal 2, Text::Qgram.similarity(word, "Solded")
    assert_equal 1, Text::Qgram.similarity(word, "Sold")
    assert_equal 0, Text::Qgram.similarity(word, "Solder")
  end

  def test_distance_with_caching
    word = "Healed"
    qgram = Text::Qgram.new
    assert_equal 4, qgram.distance(word, "Sealed")
    assert_equal 7, qgram.distance(word, "Healthy")
    assert_equal 5, qgram.distance(word, "Heard")
    assert_equal 6, qgram.distance(word, "Herded")
    assert_equal 8, qgram.distance(word, "Help")
    assert_equal 10, qgram.distance(word, "Solded")
    assert_equal 10, qgram.distance(word, "Sold")    
    assert_equal 14, qgram.distance(word, "Solder")
  end

  def test_mgrams
    assert_equal 10, Text::Qgram.mgrams("1234567890", 1).keys.size
    assert_equal 11, Text::Qgram.mgrams("1234567890", 2).keys.size
    assert_equal 12, Text::Qgram.mgrams("1234567890", 3).keys.size
    assert_equal 13, Text::Qgram.mgrams("1234567890", 4).keys.size
  end

  def test_candidate
    assert_equal true, Text::Qgram.candidate?("test", "test", 0)
    assert_equal true, Text::Qgram.candidate?("test", "test", 1)
    assert_equal false, Text::Qgram.candidate?("test", "tent", 0)
    assert_equal true,  Text::Qgram.candidate?("test", "tent", 1)
    assert_equal true,  Text::Qgram.candidate?("test", "tent", 2)
    assert_equal false,  Text::Qgram.candidate?("gumbo", "gambol", 0)
    assert_equal false,  Text::Qgram.candidate?("gumbo", "gambol", 1)
    assert_equal true,  Text::Qgram.candidate?("gumbo", "gambol", 2)
    assert_equal true,  Text::Qgram.candidate?("gumbo", "gambol", 3)
    assert_equal false,  Text::Qgram.candidate?("kitten", "sitting", 0)
    assert_equal false,  Text::Qgram.candidate?("kitten", "sitting", 1)
    assert_equal false,  Text::Qgram.candidate?("kitten", "sitting", 2)
    assert_equal true,  Text::Qgram.candidate?("kitten", "sitting", 3)
    assert_equal true,  Text::Qgram.candidate?("kitten", "sitting", 4)
  end
end
