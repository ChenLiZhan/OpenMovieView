require_relative 'spec_helper'
require_relative 'support/debut_helpers'


describe 'Prognition Stories' do
  include DebutHelpers
  describe 'Getting the root of the service' do
    it 'should return ok' do
      get '/'
      last_response.must_be :ok?
    end
  end
end
