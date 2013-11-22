require 'minitest_helper'

describe Oboe::XTrace do

  it 'should correctly validate X-Trace IDs' do
    # Invalid X-Trace IDs
    Oboe::XTrace.valid?("").must_equal false
    Oboe::XTrace.valid?(nil).must_equal false
    Oboe::XTrace.valid?("1B00000000000000000000000000000000000000000000000000000000").must_equal false
    Oboe::XTrace.valid?("1b").must_equal false
    Oboe::XTrace.valid?("29348209348").must_equal false
   
    # Standard X-Trace IDs
    Oboe::XTrace.valid?("1B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F").must_equal true
    Oboe::XTrace.valid?("1BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA").must_equal true
    Oboe::XTrace.valid?("1BADFDFB3DBA36323B2E0975925D0DAE12D10BA5946809504DC4B81FF6").must_equal true

    # X-Trace IDs with lower-case alpha chars
    Oboe::XTrace.valid?("1bf9861cb12e2a257247a8195654e56d30b2f4e2d4fce67c321ad58495").must_equal true
    Oboe::XTrace.valid?("1b258b2c1d6914f3c6085cb72e7cc93e145b401d4356aa24ef7294b2d6").must_equal true
  end

  it 'should correctly extract task IDs from X-Trace IDs' do
    task_id = Oboe::XTrace.task_id("1BF86B3D3342FCECAECE33C6411379BB171505DB6A136DFAEBDF742362")
    task_id.is_a?(String).must_equal true
    task_id.must_equal "F86B3D3342FCECAECE33C6411379BB171505DB6A"
    task_id.length.must_equal 40
    
    task_id = Oboe::XTrace.task_id("1B77970F82332EE22FF04C249FCBA8F63E8AFA2C6730E209453259B2D6")
    task_id.is_a?(String).must_equal true
    task_id.must_equal "77970F82332EE22FF04C249FCBA8F63E8AFA2C67"
    task_id.length.must_equal 40
  end

end
