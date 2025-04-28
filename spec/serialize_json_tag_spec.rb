# frozen_string_literal: true

require 'rspec'
require 'typed_struct'

describe 'タグ付きのJSONをシリアライズできる' do
  it 'キー名を変更できる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: 'other_key'
    end

    obj = c.new
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{"other_key":0}'
  end

  it 'キー名の変更とomitemptyが両方できる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: 'other_key,omitempty'
    end

    obj = c.new(n: 1)
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{"other_key":1}'

    obj = c.new(n: 0)
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{}'
  end

  it 'キー名の変更はせずにomitemptyだけができる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: ',omitempty'
      define :f, :float, json: ',omitempty'
      define :str, :string, json: ',omitempty'
      define :b, :bool, json: ',omitempty'
      define :arr, [:int], json: ',omitempty'
      define :nil, :int, json: ',omitempty', allow: 'nil'
      define :any, :any, json: ',omitempty'
    end

    obj = c.new(n: 1, f: 1.1, str: 'a', b: true, arr: [0, 1, 2], nil: 0, any: 0)
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{"n":1,"f":1.1,"str":"a","b":true,"arr":[0,1,2],"nil":0,"any":0}'

    obj = c.new(n: 0, f: 0.0, str: '', b: false, arr: [], nil: nil)
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{}'
  end

  it 'キーの省略ができる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: '-'
    end

    obj = c.new(n: 1)
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{}'

    obj = c.new(n: 0)
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{}'
  end

  it 'キーを-にできる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: '-,'
    end

    obj = c.new
    expect(TypedSerialize::JSON.marshal(obj)).to eq '{"-":0}'
  end
end

describe 'タグ付きのJSONをパースできる' do
  it 'キー名を変更できる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: 'other_key'
    end

    json = TypedSerialize::JSON.unmarshal('{"other_key":1}', c)
    expect(json).to be_a c
    expect(json.n).to eq 1
  end

  it 'キーの省略ができる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: '-'
    end

    json = TypedSerialize::JSON.unmarshal('{"-":1}', c)
    expect(json).to be_a c
    expect(json.n).to eq 0

    json = TypedSerialize::JSON.unmarshal('{"-":0}', c)
    expect(json).to be_a c
    expect(json.n).to eq 0
  end

  it 'キーを-にできる' do
    c = Class.new(TypedStruct) do
      define :n, :int, json: '-,'
    end

    json = TypedSerialize::JSON.unmarshal('{"-":1}', c)
    expect(json).to be_a c
    expect(json.n).to eq 1
  end
end
