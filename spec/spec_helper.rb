require 'vcr'
require 'fluidfeatures'

Dir["./spec/support/**/*.rb"].sort.each {|f| require f}

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :fakeweb
  c.default_cassette_options = { :record => :new_episodes }
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'

  config.extend VCR::RSpec::Macros
  config.include FluidFeatures::ApiHelpers

  config.before(:each) do
    dir = File.join(File.dirname(__FILE__), "tmp")
    FileUtils.rm_rf(dir)
  end
end
