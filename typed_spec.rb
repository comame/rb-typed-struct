# frozen_string_literal: true

require 'rspec'
require './typed'

class NormalStruct < TypedStruct
  define :n, :int
  define :str, :string
  define :f, :float
end

class PrimitiveClassStruct < TypedStruct
  define :n, Integer
end

class NestedStruct < TypedStruct
  define :nest, NestedStruct
  define :n, :int
end

class ArrayStruct < TypedStruct
  define :arr, [NormalStruct]
end

class DoubleArrayStruct < TypedStruct
  define :map, [[:int]]
end

class JSONTagStruct < TypedStruct
  define :foo, :string, json: 'foo_key,omitempty'
  define :bar, :string, json: '-'
end

describe 'TypedStruct' do
  it 'プリミティブ型の初期値を未指定' do
    v = NormalStruct.new

    expect(v.n).to eq 0
    expect(v.str).to eq ''
  end

  it 'プリミティブ型の初期値を指定した場合' do
    v = NormalStruct.new n: 53, str: 'Hello, world!'

    expect(v.n).to eq 53
    expect(v.str).to eq 'Hello, world!'

    expect { NormalStruct.new(n: '10') }.to raise_error TypeError
  end

  it 'プリミティブ型をクラスで指定した場合' do
    v = PrimitiveClassStruct.new n: 53

    expect(v.n).to eq 53
  end

  it 'プリミティブ型の初期値を部分的に指定した場合' do
    v = NormalStruct.new n: 53

    expect(v.n).to eq 53
    expect(v.str).to eq ''
  end

  it '=で代入できる' do
    v = NormalStruct.new

    v.n = 3
    expect(v.n).to eq 3

    expect { v.n = '10' }.to raise_error TypeError
  end

  it 'hash-likeに代入・取得できる' do
    v = NormalStruct.new
    v['n'] = 53
    v[:str] = 'Hello, world!'

    expect(v[:n]).to eq 53
    expect(v['str']).to eq 'Hello, world!'
  end

  it 'ネストした定義をかける' do
    v = NestedStruct.new(nest: NestedStruct.new(n: 3))

    expect(v.nest).to be_a NestedStruct
    expect(v.n).to eq 0
    expect(v.nest.nest).to eq nil
    expect(v.nest.n).to eq 3
  end

  it '配列を入れられる' do
    v = ArrayStruct.new

    expect(v.arr).to be_a Array
    expect(v.arr.length).to eq 0

    v.arr = [NormalStruct.new, NormalStruct.new(n: 53)]
    expect(v.arr).to be_a Array
    expect(v.arr.length).to eq 2
    expect(v.arr[0].n).to eq 0
    expect(v.arr[1].n).to eq 53
  end

  it '二重配列を入れられる' do
    v = DoubleArrayStruct.new

    v.map = [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
    expect(v.map).to match [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
  end
end

describe 'TypeStruct json' do
  it 'jsonに変換できる' do
    v = NormalStruct.new n: 53, str: 'Hello, world!'
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"n":53,"str":"Hello, world!","f":0.0}'

    v = NestedStruct.new(nest: NestedStruct.new(n: 3))
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"nest":{"nest":null,"n":3},"n":0}'

    v = ArrayStruct.new(arr: [NormalStruct.new, NormalStruct.new(n: 53)])
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"arr":[{"n":0,"str":"","f":0.0},{"n":53,"str":"","f":0.0}]}'

    v = [NormalStruct.new, NormalStruct.new(n: 53)]
    expect(TypedSerialize::JSON.marshal(v)).to eq '[{"n":0,"str":"","f":0.0},{"n":53,"str":"","f":0.0}]'

    v = DoubleArrayStruct.new map: [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"map":[[0,1,2],[3,4,5],[6,7,8]]}'
  end

  it 'jsonから変換できる' do
    obj = TypedSerialize::JSON.unmarshal('{"n":53,"str":"Hello, world!"}', NormalStruct)
    expect(obj.n).to eq 53
    expect(obj.str).to eq 'Hello, world!'

    array = TypedSerialize::JSON.unmarshal('{"arr":[{"n":0,"str":""},{"n":53,"str":""}]}', ArrayStruct)
    expect(array.arr.length).to eq 2
    expect(array.arr[0].n).to eq 0
    expect(array.arr[0].str).to eq ''
    expect(array.arr[1].n).to eq 53
    expect(array.arr[1].str).to eq ''

    arr = TypedSerialize::JSON.unmarshal('[{"n":53,"str":"Hello, world!"}]', [NormalStruct])
    expect(arr[0].n).to eq 53
    expect(arr[0].str).to eq 'Hello, world!'
    expect(arr.length).to eq 1

    nested = TypedSerialize::JSON.unmarshal('{"nest":{"nest":null,"n":3},"n":0}', NestedStruct)
    expect(nested.nest.nest).to eq nil
    expect(nested.nest.n).to eq 3
    expect(nested.n).to eq 0

    doubled = TypedSerialize::JSON.unmarshal('{"map":[[0,1,2],[3,4,5],[6,7,8]]}', DoubleArrayStruct)
    expect(doubled.map).to match [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
  end

  it 'jsonからのパース時、型が違ったらエラーを吐ける' do
    expect { TypedSerialize::JSON.unmarshal('{"n":"53"}', NormalStruct) }.to raise_error TypeError
  end

  it 'jsonからのパース時、値が指定されていなければzero-valueが入る' do
    obj = TypedSerialize::JSON.unmarshal('{}', NormalStruct)
    expect(obj.n).to eq 0
    expect(obj.str).to eq ''
  end
end
