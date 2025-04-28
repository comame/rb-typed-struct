# frozen_string_literal: true

require 'rspec'
require 'typed_struct'

describe 'JSON' do
  it 'marshalできる' do
    c = Class.new(TypedStruct) do
      define :n, :int
    end

    obj = c.new(n: 3)
    json = TypedSerialize::JSON.marshal obj
    expect(json).to eq '{"n":3}'
  end

  it 'unmarshalできる' do
    c = Class.new(TypedStruct) do
      define :n, :int
    end

    json = '{"n":3}'
    obj = TypedSerialize::JSON.unmarshal(json, c)

    expect(obj.n).to eq 3
  end
end
