# frozen_string_literal: true

require 'rspec'
require 'typed_struct'

describe 'Hash に変換できる' do
  it 'プリミティブ型' do
    c = Class.new(TypedStruct) do
      define :n, :int
      define :f, :float
      define :str, :string
      define :b, :bool
      define :sym, :symbol
    end

    obj = c.new(n: 1, f: 1.1, str: 'hello', b: true, sym: :foo)
    hash = TypedSerialize::Hash.marshal obj

    expect(hash).to eq({ 'n' => 1, 'f' => 1.1, 'str' => 'hello', 'b' => true, 'sym' => :foo })
  end

  it '配列型 (プリミティブ型を含む)' do
    c = Class.new(TypedStruct) do
      define :arr, [:int]
    end

    obj = c.new(arr: [1, 2])
    hash = TypedSerialize::Hash.marshal obj

    expect(hash).to eq({ 'arr' => [1, 2] })
  end

  it '配列型 (構造体を含む)' do
    other = Class.new(TypedStruct) do
      define :n, :int
    end

    c = Class.new(TypedStruct) do
      define :arr, [other]
    end

    obj = c.new(arr: [other.new, other.new(n: 1)])
    hash = TypedSerialize::Hash.marshal obj

    expect(hash).to eq({ 'arr' => [{ 'n' => 0 }, { 'n' => 1 }] })
  end

  it '配列型 (ネストした)' do
    c = Class.new(TypedStruct) do
      define :arr, [[:int]]
    end

    obj = c.new(arr: [[1, 2, 3], [4, 5, 6]])
    hash = TypedSerialize::Hash.marshal obj

    expect(hash).to eq({ 'arr' => [[1, 2, 3], [4, 5, 6]] })
  end

  it '構造体型' do
    other = Class.new(TypedStruct) do
      define :n, :int
    end

    c = Class.new(TypedStruct) do
      define :a, other
    end

    obj = c.new(a: other.new(n: 1))
    hash = TypedSerialize::Hash.marshal obj

    expect(hash).to eq({ 'a' => { 'n' => 1 } })
  end

  it 'nil許容型' do
    c = Class.new(TypedStruct) do
      define :n, :int, allow: 'nil'
    end

    obj = c.new(n: nil)
    hash = TypedSerialize::Hash.marshal obj

    expect(hash).to eq({ 'n' => nil })
  end
end

describe 'Hashから変換できることを型ごとにチェック' do
  it 'プリミティブ型' do
    c = Class.new(TypedStruct) do
      define :n, :int
      define :f, :float
      define :str, :string
      define :b, :bool
      define :sym, :symbol
    end

    hash = { 'n' => 1, 'f' => 1.1, 'str' => 'hello', 'b' => true, 'sym' => :foo }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj).to be_a c

    expect(obj.n).to eq 1
    expect(obj.f).to eq 1.1
    expect(obj.str).to eq 'hello'
    expect(obj.b).to eq true
    expect(obj.sym).to eq :foo
  end

  it '配列型 (プリミティブ型を含む)' do
    c = Class.new(TypedStruct) do
      define :arr, [:int]
    end

    hash = { 'arr' => [1, 2] }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.arr).to eq [1, 2]
  end

  it '配列型 (構造体を含む)' do
    other = Class.new(TypedStruct) do
      define :n, :int
    end

    c = Class.new(TypedStruct) do
      define :arr, [other]
    end

    hash = { 'arr' => [{ 'n' => 0 }, { 'n' => 1 }] }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.arr.length).to eq 2
    expect(obj.arr[0].n).to eq 0
    expect(obj.arr[1].n).to eq 1
  end

  it '配列型 (ネストした)' do
    c = Class.new(TypedStruct) do
      define :arr, [[:int]]
    end

    hash = { 'arr' => [[1, 2, 3], [4, 5, 6]] }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.arr).to eq [[1, 2, 3], [4, 5, 6]]
  end

  it '構造体型' do
    other = Class.new(TypedStruct) do
      define :n, :int
    end

    c = Class.new(TypedStruct) do
      define :a, other
    end

    hash = { 'a' => { 'n' => 1 } }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.a.n).to eq 1
  end

  it '構造体の配列' do
    c = Class.new(TypedStruct) do
      define :n, :int
    end

    hash = [{ 'n' => 1 }, { 'n' => 2 }]
    obj = TypedSerialize::Hash.unmarshal hash, [c]

    expect(obj.length).to eq 2
    expect(obj[0].n).to eq 1
    expect(obj[1].n).to eq 2
  end

  it 'any型' do
    c = Class.new(TypedStruct) do
      define :value, :any
    end

    hash = { 'value' => 1 }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.value).to eq 1

    hash = { 'value' => { 'a' => 'b' } }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.value).to be_a Hash
    expect(obj.value).to eq({ 'a' => 'b' })

    hash = { 'value' => %w[a b] }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.value).to be_a Array
    expect(obj.value).to eq(%w[a b])
  end
end

describe '初期値' do
  it 'Hashに値がなかったら初期値が入ることをチェック' do
    c = Class.new(TypedStruct) do
      define :a, :int
      define :b, :int
    end

    hash = { 'a' => 1 }
    obj = TypedSerialize::Hash.unmarshal hash, c

    expect(obj.a).to eq 1
    expect(obj.b).to eq 0
  end
end
