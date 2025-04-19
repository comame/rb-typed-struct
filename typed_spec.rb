# frozen_string_literal: true

require 'rspec'
require 'json'
require './typed'

class StructA < TypedStruct
  define :n, :int
  define :str, :string
end

class StructB < TypedStruct
  define :n, :int
end

class StructC < TypedStruct
  define :nest, StructC
  define :n, :int
end

describe 'TypedStruct' do
  it 'プリミティブ型の初期値を未指定' do
    v = StructA.new

    expect(v.n).to eq 0
    expect(v.str).to eq ''
  end

  it 'プリミティブ型の初期値を指定した場合' do
    v = StructA.new n: 53, str: 'Hello, world!'

    expect(v.n).to eq 53
    expect(v.str).to eq 'Hello, world!'
  end

  it 'プリミティブ型の初期値を部分的に指定した場合' do
    v = StructA.new n: 53

    expect(v.n).to eq 53
    expect(v.str).to eq ''
  end

  it '=で代入できる' do
    v = StructB.new

    v.n = 3
    expect(v.n).to eq 3

    expect { v.n = '10' }.to raise_error TypeError
  end

  it '初期化時に値を指定できる' do
    expect(StructB.new(n: 3).n).to eq 3
    expect { StructB.new(n: '10') }.to raise_error TypeError
  end

  it 'hash-likeに代入・取得できる' do
    v = StructA.new
    v['n'] = 53
    v[:str] = 'Hello, world!'

    expect(v[:n]).to eq 53
    expect(v['str']).to eq 'Hello, world!'
  end

  it 'ネストした定義をかける' do
    v = StructC.new(nest: StructC.new(n: 3))

    expect(v.nest).to be_a StructC
    expect(v.n).to eq 0
    expect(v.nest.nest).to eq nil
    expect(v.nest.n).to eq 3
  end
end

describe 'TypeStruct json' do
  it 'jsonに変換できる' do
    v = StructA.new n: 53, str: 'Hello, world!'
    expect(v.to_json).to eq '{"n":53,"str":"Hello, world!"}'

    v = StructC.new(nest: StructC.new(n: 3))
    expect(v.to_json).to eq '{"nest":{"nest":null,"n":3},"n":0}'
  end

  it 'jsonから変換できる' do
    obj = JSON.parse('{"n":53,"str":"Hello, world!"}', object_class: StructA)
    expect(obj.n).to eq 53
    expect(obj.str).to eq 'Hello, world!'

    arr = JSON.parse('[{"n":53,"str":"Hello, world!"}]', object_class: StructA)
    expect(arr[0].n).to eq 53
    expect(arr[0].str).to eq 'Hello, world!'
    expect(arr.length).to eq 1

    nested = JSON.parse('{"nest":{"nest":null,"n":3},"n":0}', object_class: StructC)
    expect(nested.nest.nest).to eq nil
    expect(nested.nest.n).to eq 3
    expect(nested.n).to eq 0
  end

  it 'jsonからのパース時、型が違ったらエラーを吐ける' do
    expect { JSON.parse('{"n":"53"}', object_class: StructB) }.to raise_error TypeError
  end

  it 'jsonからのパース時、値が指定されていなければzero-valueが入る' do
    obj = JSON.parse('{}', object_class: StructB)
    expect(obj.n).to eq 0
  end
end
