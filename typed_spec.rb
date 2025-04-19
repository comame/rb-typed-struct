# frozen_string_literal: true

require 'rspec'
require './typed'

describe 'TypedStruct' do
  it 'プリミティブ型の初期値を未指定' do
    c = Class.new TypedStruct do
      define :n, :int
      define :str, :string
    end

    v = c.new

    expect(v.n).to eq 0
    expect(v.str).to eq ''
  end

  it 'プリミティブ型の初期値を指定した場合' do
    c = Class.new TypedStruct do
      define :n, :int
      define :str, :string
    end

    v = c.new n: 53, str: 'Hello, world!'

    expect(v.n).to eq 53
    expect(v.str).to eq 'Hello, world!'
  end

  it 'プリミティブ型の初期値を部分的に指定した場合' do
    c = Class.new TypedStruct do
      define :n, :int
      define :str, :string
    end

    v = c.new n: 53

    expect(v.n).to eq 53
    expect(v.str).to eq ''
  end

  it 'safe_assign で代入できる' do
    c = Class.new TypedStruct do
      define :n, :int
    end

    v = c.new

    ok = v.safe_assign :n, 3
    expect(ok).to be true
    expect(v.n).to eq 3

    ok = v.safe_assign :n, '30'
    expect(ok).to be false
    expect(v.n).to eq 3
  end

  it '=で代入できる' do
    c = Class.new TypedStruct do
      define :n, :int
    end

    v = c.new

    v.n = 3
    expect(v.n).to eq 3

    expect { v.n = '10' }.to raise_error TypeError
  end

  it '初期化時に値を指定できる' do
    c = Class.new TypedStruct do
      define :n, :int
    end
    expect(c.new(n: 3).n).to eq 3

    expect { c.new(n: '10') }.to raise_error TypeError
  end
end
