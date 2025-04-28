# frozen_string_literal: true

require 'rspec'
require 'typed_struct'

describe 'YAML' do
  it 'marshalできる' do
    c = Class.new(TypedStruct) do
      define :num, :int
    end

    obj = c.new(num: 3)
    yaml = TypedSerialize::YAML.marshal obj
    expect(yaml).to eq <<~YAML
      num: 3
    YAML
  end

  it 'unmarshalできる' do
    c = Class.new(TypedStruct) do
      define :num, :int
    end

    yaml = <<~YAML
      num: 3
    YAML
    obj = TypedSerialize::YAML.unmarshal(yaml, c)

    expect(obj.num).to eq 3
  end
end
