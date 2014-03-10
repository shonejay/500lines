require 'test/unit'
require_relative '../../models/analyzer'

class AnalyzerTest < Test::Unit::TestCase

  PARSER_MESSAGE = 'Parser invalid.'
  USER_MESSAGE   = 'User invalid.'

  # -- Creation Tests -------------------------------------------------------

  def test_create_accelerometer_data
    user = User.new
    device = Device.new('0.123,-0.123,5;')
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser, user)
    
    assert_equal parser, analyzer.parser
    assert_equal 0, analyzer.steps
    assert_equal 0, analyzer.distance
    assert_equal 0, analyzer.time
    assert_equal user,  analyzer.user
    assert_equal 'sec', analyzer.time_interval
    assert_equal 'cm',  analyzer.distance_interval
  end

  def test_create_gravity_data
    user = User.new
    device = Device.new('0.028,-0.072,5|0.129,-0.945,-5;')
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser, user)
    
    assert_equal parser, analyzer.parser
    assert_equal 0, analyzer.steps
    assert_equal 0, analyzer.distance
    assert_equal 0, analyzer.time
    assert_equal user,      analyzer.user
    assert_equal 'sec', analyzer.time_interval
    assert_equal 'cm',      analyzer.distance_interval
  end

  def test_create_no_parser
    assert_raise_with_message(RuntimeError, PARSER_MESSAGE) do
      Analyzer.new(nil)
    end
  end

  def test_create_bad_parser
    assert_raise_with_message(RuntimeError, PARSER_MESSAGE) do
      Analyzer.new('bad device data')
    end
  end

  def test_create_no_user
    device = Device.new('0.123,-0.123,5;')
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    assert analyzer.user.kind_of? User
  end

  def test_create_bad_user
    assert_raise_with_message(RuntimeError, USER_MESSAGE) do
      device = Device.new('0.123,-0.123,5;')
      parser = Parser.new(device)
      analyzer = Analyzer.new(parser, 'bad user')
    end
  end

  # -- Edge Detection Tests -------------------------------------------------

  def test_split_on_threshold
    device = Device.new(File.read('test/data/female-167-70_100-walk-10-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)

    expected = File.read('test/data/expected/female-167-70_100-walk-10-1-g-positive.txt').split(',').collect(&:to_i)
    assert_equal expected, analyzer.split_on_threshold(true)

    expected = File.read('test/data/expected/female-167-70_100-walk-10-1-g-negative.txt').split(',').collect(&:to_i)
    assert_equal expected, analyzer.split_on_threshold(false)
  end

  def test_detect_edges
    device = Device.new(File.read('test/data/female-167-70_100-walk-10-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    
    assert_equal 9, analyzer.detect_edges(analyzer.split_on_threshold(true))
    assert_equal 7, analyzer.detect_edges(analyzer.split_on_threshold(false))
  end

  def test_detect_edges_false_step
    device = Device.new(File.read('test/data/female-167-70_100-walk-0-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    
    assert_equal 1, analyzer.detect_edges(analyzer.split_on_threshold(true))
    assert_equal 1, analyzer.detect_edges(analyzer.split_on_threshold(false))    
  end

  # -- Measurement Tests ----------------------------------------------------

  def test_measure_steps
    device = Device.new(File.read('test/data/female-167-70_100-walk-10-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    analyzer.send(:measure_steps)
    assert_equal 8, analyzer.steps
  end

  def test_measure_distance_before_steps
    device = Device.new(File.read('test/data/female-167-70_100-walk-10-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    analyzer.send(:measure_distance)
    assert_equal 0, analyzer.distance
  end

  def test_measure_distance_cm
    device = Device.new(File.read('test/data/results-0-steps.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    analyzer.send(:measure_steps)
    analyzer.send(:measure_distance)
    
    assert_equal 0, analyzer.distance
    assert_equal 'cm', analyzer.distance_interval
  end

  def test_measure_distance_m
    user = User.new(nil, nil, 100)
    device = Device.new(File.read('test/data/female-167-70_100-walk-10-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser, user)
    analyzer.send(:measure_steps)
    analyzer.send(:measure_distance)

    assert_equal 8.0, analyzer.distance
    assert_equal 'm', analyzer.distance_interval
  end

  def test_measure_distance_km
    user = User.new(nil, nil, 100000)
    device = Device.new(File.read('test/data/female-167-70_100-walk-10-1-g.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser, user)
    analyzer.send(:measure_steps)
    analyzer.send(:measure_distance)
    
    assert_equal 8.0, analyzer.distance
    assert_equal 'km', analyzer.distance_interval 
  end

  def test_measure_time_seconds
    device = Device.new(File.read('test/data/results-15-steps.txt'), 4)
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    analyzer.send(:measure_time)
    
    assert_equal 7.25, analyzer.time
    assert_equal 'sec', analyzer.time_interval
  end

  def test_measure_time_minutes
    # Fake out 1000 samples
    device = Device.new((1000.times.inject('') {|a| a+='1,1,1;';a}), 4)
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    analyzer.send(:measure_time)
    
    assert_equal 4.17, analyzer.time
    assert_equal 'minutes', analyzer.time_interval
  end

  def test_measure_time_hours
    # Fake out 15000 samples
    device = Device.new((15000.times.inject('') {|a| a+='1,1,1;';a}), 4)
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser)
    analyzer.send(:measure_time)

    assert_equal 1.04, analyzer.time
    assert_equal 'hours', analyzer.time_interval
  end

  def test_measure
    user = User.new(nil, nil, 65)
    device = Device.new(File.read('test/data/results-0-steps.txt'), 5)
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser, user)
    analyzer.measure

    assert_equal 0, analyzer.steps
    assert_equal 0, analyzer.distance
    assert_equal 0.2, analyzer.time
    assert_equal 'sec', analyzer.time_interval
    
    device = Device.new(File.read('test/data/results-15-steps.txt'))
    parser = Parser.new(device)
    analyzer = Analyzer.new(parser, user)
    analyzer.measure

    # TODO: This data is way off because the accelerometer filter
    #       doesn't use the user data (specifically the rate)
    assert_equal 0, analyzer.steps
    assert_equal 0, analyzer.distance
    assert_equal 0.29, analyzer.time
    assert_equal 'sec', analyzer.time_interval

    # assert_equal 15, analyzer.steps
    # assert_equal 975, analyzer.distance
    # assert_equal 5.8, analyzer.time
    # assert_equal 'sec', analyzer.interval
  end

end