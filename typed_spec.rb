# frozen_string_literal: true

require 'rspec'
require 'json'
require './typed'

class NormalStruct < TypedStruct
  define :n, :int
  define :str, :string
end

class NestedStruct < TypedStruct
  define :nest, NestedStruct
  define :n, :int
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
end

describe 'TypeStruct json' do
  it 'jsonに変換できる' do
    v = NormalStruct.new n: 53, str: 'Hello, world!'
    expect(TypedSerde::JSON.marshal(v)).to eq '{"n":53,"str":"Hello, world!"}'

    v = NestedStruct.new(nest: NestedStruct.new(n: 3))
    expect(TypedSerde::JSON.marshal(v)).to eq '{"nest":{"nest":null,"n":3},"n":0}'
  end

  it 'jsonから変換できる' do
    obj = JSON.parse('{"n":53,"str":"Hello, world!"}', object_class: NormalStruct)
    expect(obj.n).to eq 53
    expect(obj.str).to eq 'Hello, world!'

    arr = JSON.parse('[{"n":53,"str":"Hello, world!"}]', object_class: NormalStruct)
    expect(arr[0].n).to eq 53
    expect(arr[0].str).to eq 'Hello, world!'
    expect(arr.length).to eq 1

    nested = JSON.parse('{"nest":{"nest":null,"n":3},"n":0}', object_class: NestedStruct)
    expect(nested.nest.nest).to eq nil
    expect(nested.nest.n).to eq 3
    expect(nested.n).to eq 0
  end

  it 'jsonからのパース時、型が違ったらエラーを吐ける' do
    expect { JSON.parse('{"n":"53"}', object_class: NormalStruct) }.to raise_error TypeError
  end

  it 'jsonからのパース時、値が指定されていなければzero-valueが入る' do
    obj = JSON.parse('{}', object_class: NormalStruct)
    expect(obj.n).to eq 0
    expect(obj.str).to eq ''
  end
end
