# frozen_string_literal: true

require 'rspec'
require 'typed_struct'

describe '代入時に型チェックできるかどうか？' do
  it 'プリミティブ型' do
    c = Class.new(TypedStruct) do
      define :n, :int
      define :f, :float
      define :str, :string
      define :b, :bool
      define :sym, :symbol
    end

    obj = c.new

    obj.n = 1
    expect(obj.n).to eq 1
    expect { obj.n = 'one' }.to raise_error TypeError
    expect { obj.n = nil }.to raise_error TypeError

    obj.f = 1.1
    expect(obj.f).to eq 1.1
    expect { obj.f = 'one' }.to raise_error TypeError
    expect { obj.f = nil }.to raise_error TypeError

    obj.str = 'hello'
    expect(obj.str).to eq 'hello'
    expect { obj.str = 1 }.to raise_error TypeError
    expect { obj.str = nil }.to raise_error TypeError

    obj.b = true
    expect(obj.b).to eq true
    expect { obj.b = 'true' }.to raise_error TypeError
    expect { obj.b = nil }.to raise_error TypeError

    obj.sym = :foo
    expect(obj.sym).to eq :foo
    expect { obj.sym = 'foo' }.to raise_error TypeError
    expect { obj.sym = nil }.to raise_error TypeError
  end

  it '配列型 (プリミティブ型を含む)' do
    c = Class.new(TypedStruct) do
      define :arr, [:int]
    end

    obj = c.new

    obj.arr = [1, 2, 3]
    expect(obj.arr).to eq [1, 2, 3]

    obj.arr = []
    expect(obj.arr).to eq []

    expect { obj.arr = ['one'] }.to raise_error TypeError
    expect { obj.arr = nil }.to raise_error TypeError
  end

  it '配列型 (構造体を含む)' do
    other = Class.new(TypedStruct) do
      define :n, :int
    end

    c = Class.new(TypedStruct) do
      define :arr, [other]
    end

    obj = c.new

    obj.arr = [other.new, other.new(n: 1)]
    expect(obj.arr.length).to eq 2
    expect(obj.arr[0].n).to eq 0
    expect(obj.arr[1].n).to eq 1
  end

  it '配列型 (ネストした)' do
    c = Class.new(TypedStruct) do
      define :arr, [[:int]]
    end

    obj = c.new

    obj.arr = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    expect(obj.arr).to eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    obj.arr = []
    expect(obj.arr).to eq []

    expect { obj.arr = [1, 2, 3] }.to raise_error TypeError
    expect { obj.arr = [['one']] }.to raise_error TypeError
  end

  it '構造体型' do
    other = Class.new(TypedStruct) do
      define :n, :int
    end

    c = Class.new(TypedStruct) do
      define :a, other
    end

    obj = c.new

    obj.a = other.new(n: 1)
    expect(obj.a.n).to eq 1

    expect { obj.a = c.new }.to raise_error TypeError
    expect { obj.a = nil }.to raise_error TypeError
  end

  it 'nil許容型' do
    c = Class.new(TypedStruct) do
      define :n, :int, allow: 'nil'
    end

    obj = c.new

    obj.n = 1
    expect(obj.n).to eq 1

    obj.n = nil
    expect(obj.n).to eq nil

    expect { obj.n = 'one' }.to raise_error TypeError
  end
end

describe '初期化時に型チェックできるかどうか？' do
  it 'プリミティブ型' do
    c = Class.new(TypedStruct) do
      define :n, :int
    end

    expect { c.new(n: 'one') }.to raise_error TypeError
  end
end

describe '初期値が正しいかどうか？' do
  it 'プリミティブ型' do
    c = Class.new(TypedStruct) do
      define :n, :int
      define :f, :float
      define :str, :string
      define :b, :bool
      define :sym, :symbol
    end

    obj = c.new

    expect(obj.n).to eq 0
    expect(obj.f).to eq 0.0
    expect(obj.str).to eq ''
    expect(obj.b).to eq false
    expect(obj.sym).to eq :''
  end

  it '配列型' do
    c = Class.new(TypedStruct) do
      define :arr, [:int]
    end

    obj = c.new
    expect(obj.arr).to eq []
  end

  it '構造体型' do
    alpha = Class.new(TypedStruct) do
      define :n, :int
    end
    beta = Class.new(TypedStruct) do
      define :a, alpha
    end

    obj = beta.new
    expect(obj.a.n).to eq 0
  end

  it 'nil許容型' do
    c = Class.new(TypedStruct) do
      define :n, :int, allow: 'nil'
    end

    obj = c.new
    expect(obj.n).to eq nil
  end
end

describe '不正な型定義をはじけるか？' do
  it 'プリミティブ型のシンボル' do
    expect do
      Class.new(TypedStruct) do
        define :invalid, :invalid_symbol
      end
    end.to raise_error ArgumentError
  end

  it '不正な配列型' do
    expect do
      Class.new(TypedStruct) do
        define :invalid, []
      end
    end.to raise_error ArgumentError

    expect do
      Class.new(TypedStruct) do
        define :invalid, [0]
      end
    end.to raise_error ArgumentError

    expect do
      Class.new(TypedStruct) do
        define :invalid, [:invalid_symbol]
      end
    end.to raise_error ArgumentError

    expect do
      Class.new(TypedStruct) do
        define :invalid, %i[int int]
      end
    end.to raise_error ArgumentError
  end

  it '不正なクラス' do
    expect do
      Class.new(TypedStruct) do
        define :invalid, Hash
      end
    end.to raise_error ArgumentError
  end
end

describe 'Any型' do
  it '代入時の型チェック' do
    c = Class.new(TypedStruct) do
      define :value, :any
    end

    obj = c.new

    obj.value = 1
    expect(obj.value).to eq 1

    obj.value = 'one'
    expect(obj.value).to eq 'one'

    obj.value = nil
    expect(obj.value).to eq nil

    obj.value = [0, 1, 2]
    expect(obj.value).to eq [0, 1, 2]

    obj.value = { a: 'b' }
    expect(obj.value).to eq({ a: 'b' })
  end
end
