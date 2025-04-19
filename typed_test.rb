require 'rspec'
require './typed'

describe 'TypedStruct' do
  it 'プリミティブ型の初期値を未指定' do
    c = Class.new Typed::TypedStruct do
      define :n, :int
      define :str, :string
    end

    v = c.new

    expect(v.n).to eq 0
    expect(v.str).to eq ''
  end

  it 'プリミティブ型の初期値を指定した場合' do
    c = Class.new Typed::TypedStruct do
      define :n, :int
      define :str, :string
    end

    v = c.new n: 53, str: 'Hello, world!'

    expect(v.n).to eq 53
    expect(v.str).to eq 'Hello, world!'
  end

  it 'プリミティブ型の初期値を部分的に指定した場合' do
    c = Class.new Typed::TypedStruct do
      define :n, :int
      define :str, :string
    end

    v = c.new n: 53

    expect(v.n).to eq 53
    expect(v.str).to eq ''
  end
end
