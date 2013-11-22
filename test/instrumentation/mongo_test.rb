require 'minitest_helper'

describe Oboe::Inst::Mongo do
  before do
    clear_all_traces 
    @connection = Mongo::Connection.new("localhost", 27017, :slave_ok => true)
    @db = @connection.db("test-#{ENV['RACK_ENV']}")

    @collections = @db.collection_names
    @db.create_collection("testCollection") unless @collections.include? "testCollection"

    # These are standard entry/exit KVs that are passed up with all mongo operations
    @entry_kvs = {
      'Layer' => 'mongo',
      'Label' => 'entry',
      'Flavor' => 'mongodb',
      'Database' => 'test-test',
      'RemoteHost' => 'localhost',
      'RemotePort' => '27017' }

    @exit_kvs = { 'Layer' => 'mongo', 'Label' => 'exit' }
    @collect_backtraces = Oboe::Config[:mongo][:collect_backtraces]
  end
  
  after do
    Oboe::Config[:mongo][:collect_backtraces] = @collect_backtraces
  end

  it 'Stock Mongo should be loaded, defined and ready' do
    defined?(::Mongo).wont_match nil 
    defined?(::Mongo::DB).wont_match nil
    defined?(::Mongo::Cursor).wont_match nil
    defined?(::Mongo::Collection).wont_match nil
  end

  it 'Mongo should have oboe methods defined' do
    Oboe::Inst::Mongo::DB_OPS.each do |m|
      ::Mongo::DB.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::CURSOR_OPS.each do |m|
      ::Mongo::Cursor.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::COLL_WRITE_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::COLL_QUERY_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    Oboe::Inst::Mongo::COLL_INDEX_OPS.each do |m|
      ::Mongo::Collection.method_defined?("#{m}_with_oboe").must_equal true
    end
    ::Mongo::Collection.method_defined?(:oboe_collect).must_equal true
  end

  it "should trace create_collection" do
    Oboe::API.start_trace('mongo_test', '', {}) do
      @db.create_collection("create_and_drop_collection_test")
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)

    traces[1]['QueryOp'].must_equal "create_collection"
    traces[1]['New_Collection_Name'].must_equal "create_and_drop_collection_test"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
  end

  it "should trace drop_collection" do
    # Create a collection so we have one to drop
    @db.create_collection("create_and_drop_collection_test")
    
    Oboe::API.start_trace('mongo_test', '', {}) do
      @db.drop_collection("create_and_drop_collection_test")
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)

    traces[1]['QueryOp'].must_equal "drop_collection"
    traces[1]['Collection'].must_equal "create_and_drop_collection_test"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
  end

  it "should trace count" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.count(:query => {:name => "MyName"})
    end
    
    traces = get_all_traces
    traces.count.must_equal 6

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)

    traces[3]['QueryOp'].must_equal "count"
  end
  
  it "should trace find_and_modify" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.find_and_modify({ :query => { :name => "MyName" }, :update => { :count => 203 }})
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)

    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "find_and_modify"
    traces[1]['Update_Document'].must_equal "{:count=>203}"
  end
  
  it "should trace insert" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      id = coll.insert(doc)
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "insert"
    # Don't test exact hash value since to_json hash ordering varies between 1.8.7 and 1.9+
    traces[1].has_key?('Query').must_equal true
  end
  
  it "should trace map_reduce" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      map    = "function() { emit(this.name, 1); }"
      reduce = "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
      coll.map_reduce(map, reduce, { :out => "mr_results", :limit => 100, :read => :primary })
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "map_reduce"
    traces[1]['Map_Function'].must_equal "function() { emit(this.name, 1); }"
    traces[1]['Reduce_Function'].must_equal "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
    traces[1]['Limit'].must_equal "100"
  end
  
  it "should trace remove" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.remove(:name => "SaveOp")
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)

    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "remove"
    traces[1]['Query'].must_equal "{\"name\":\"SaveOp\"}"
  end
  
  it "should trace rename" do
    coll = @db.collection("testCollection")
    new_name = (0...10).map{ ('a'..'z').to_a[rand(26)] }.join

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.rename(new_name)
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "rename"
    traces[1]['New_Collection_Name'].must_equal new_name
    
    # Clean up after test and set collection name back to original
    coll.rename("testCollection")
  end

  it "should trace update" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      # Two types of update calls
      coll.update({"_id" => 1}, { "$set" => {"name" => "MongoDB Ruby"}}, :multi => true)
      
      doc = {"name" => "MyOtherName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.update({"_id" => 1}, doc)
    end
    
    traces = get_all_traces
    traces.count.must_equal 6

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "update"
    traces[1]['Query'].must_equal "{\"_id\":1}"
    
    validate_event_keys(traces[3], @entry_kvs)
    validate_event_keys(traces[4], @exit_kvs)

    traces[3].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[3]['QueryOp'].must_equal "update"
    traces[3]['Query'].must_equal "{\"_id\":1}"
  end
  
  it "should trace distinct" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.distinct("count")
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "distinct"
  end
  
  it "should trace find" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.find(:name => "MyName", :limit => 1)
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)

    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "find"
    traces[1].has_key?('Query').must_equal true
    traces[1]['Limit'].must_equal "1"
  end
  
  it "should trace group" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.group( :key =>  :type,
                  :cond => { :count => 1 },
                  :initial =>  { :count => 0 },
                  :reduce => 'function(obj,prev) { prev.count += obj.c; }')
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "group"
    # Don't test exact hash value since to_json hash ordering varies between 1.8.7 and 1.9+
    traces[1].has_key?('Query').must_equal true
  end

  it "should trace create, ensure and drop index" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.create_index("i")
      coll.ensure_index("i")
      coll.drop_index("i_1")
    end
    
    traces = get_all_traces
    traces.count.must_equal 8

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "create_index"

    validate_event_keys(traces[3], @entry_kvs)
    validate_event_keys(traces[4], @exit_kvs)

    traces[3]['Collection'].must_equal "testCollection"
    traces[3].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[3]['QueryOp'].must_equal "ensure_index"

    validate_event_keys(traces[5], @entry_kvs)
    validate_event_keys(traces[6], @exit_kvs)

    traces[5]['Collection'].must_equal "testCollection"
    traces[5].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[5]['QueryOp'].must_equal "drop_index"
  end
  
  it "should trace drop_indexes" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.drop_indexes
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "drop_indexes"
  end
  
  it "should trace index_information" do
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      coll.index_information
    end
    
    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'mongo_test')
    validate_event_keys(traces[1], @entry_kvs)
    validate_event_keys(traces[2], @exit_kvs)
    
    traces[1]['Collection'].must_equal "testCollection"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:mongo][:collect_backtraces]
    traces[1]['QueryOp'].must_equal "index_information"
  end
  
  it "should obey :collect_backtraces setting when true" do
    Oboe::Config[:mongo][:collect_backtraces] = true
    
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      id = coll.insert(doc)
    end

    traces = get_all_traces
    layer_has_key(traces, 'mongo', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    Oboe::Config[:mongo][:collect_backtraces] = false
    
    coll = @db.collection("testCollection")

    Oboe::API.start_trace('mongo_test', '', {}) do
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      id = coll.insert(doc)
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'mongo', 'Backtrace')
  end
end
