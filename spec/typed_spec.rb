# frozen_string_literal: true

require 'rspec'

require 'typed_struct'

# 代入時に型チェックされる構造体を記述できる
class NormalStruct < TypedStruct
  define :n, :int
  define :str, :string
  define :f, :float
end

# boolean (= TrueClass or FalseClass) を記述できる
class BoolStruct < TypedStruct
  define :b, :bool
end

# クラスによってもプリミティブを指定できる (非推奨)
class PrimitiveClassStruct < TypedStruct
  define :n, Integer
end

# ネストした構造体を記述できる
class NestedStruct < TypedStruct
  define :nest, NormalStruct
end

# 配列を含んだ構造体を記述できる
class ArrayStruct < TypedStruct
  define :arr_struct, [NormalStruct]
  define :arr_int, [:int]
end

# 二重配列を記述できる
class DoubleArrayStruct < TypedStruct
  define :map, [[:int]]
end

# nil を許容できる。デフォルトでは :any に対してのみ nil が許容される。
class NilableStruct < TypedStruct
  define :n, :int, allow: 'nil'
end

class SymbolStruct < TypedStruct
  define :sym, :symbol
end

describe 'TypedStruct の基本操作' do
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
    v = NestedStruct.new(nest: NormalStruct.new(n: 3))

    expect(v.nest).to be_a NormalStruct
    expect(v.nest.n).to eq 3
  end

  it '配列を入れられる' do
    v = ArrayStruct.new

    expect(v.arr_struct).to be_a Array
    expect(v.arr_struct.length).to eq 0

    v.arr_struct = [NormalStruct.new, NormalStruct.new(n: 53)]
    expect(v.arr_struct).to be_a Array
    expect(v.arr_struct.length).to eq 2
    expect(v.arr_struct[0].n).to eq 0
    expect(v.arr_struct[1].n).to eq 53

    v.arr_int = [0, 1, 2]
    expect(v.arr_int).to match [0, 1, 2]

    v.arr_int = []
    expect(v.arr_int).to match []

    expect { v.arr_int = ['str'] }.to raise_error TypeError
  end

  it '二重配列を入れられる' do
    v = DoubleArrayStruct.new

    v.map = [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
    expect(v.map).to match [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
  end

  it 'booleanを表現できる' do
    v = BoolStruct.new b: true
    expect(v.b).to eq true

    v = BoolStruct.new b: false
    expect(v.b).to eq false
  end

  it 'nil代入を許容しない' do
    normal = NormalStruct.new
    expect { normal.n = nil }.to raise_error TypeError
    expect { normal.str = nil }.to raise_error TypeError
    expect { normal.f = nil }.to raise_error TypeError

    bool = BoolStruct.new
    expect { bool.b = nil }.to raise_error TypeError

    nested = NestedStruct.new
    expect { nested.nest = nil }.to raise_error TypeError

    array = ArrayStruct.new
    expect { array.arr_struct = nil }.to raise_error TypeError
  end

  it 'nil許容' do
    # nil許容型の初期値はnil
    zero = NilableStruct.new
    expect(zero.n).to eq nil

    filled = NilableStruct.new(n: 1)
    expect(filled.n).to eq 1
    filled.n = nil
    expect(filled.n).to eq nil
  end

  it 'symbol型の定義' do
    foo = SymbolStruct.new(sym: :foo)
    expect(foo.sym).to eq :foo

    expect { foo.sym = 'foo' }.to raise_error TypeError
  end
end

describe 'TypeStruct で JSON を扱える' do
  it 'jsonに変換できる' do
    v = NormalStruct.new n: 53, str: 'Hello, world!'
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"n":53,"str":"Hello, world!","f":0.0}'

    v = NestedStruct.new(nest: NormalStruct.new(n: 3))
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"nest":{"n":3,"str":"","f":0.0}}'

    v = ArrayStruct.new(arr_struct: [NormalStruct.new, NormalStruct.new(n: 53)], arr_int: [0, 1, 2])
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"arr_struct":[{"n":0,"str":"","f":0.0},{"n":53,"str":"","f":0.0}],"arr_int":[0,1,2]}'

    v = [NormalStruct.new, NormalStruct.new(n: 53)]
    expect(TypedSerialize::JSON.marshal(v)).to eq '[{"n":0,"str":"","f":0.0},{"n":53,"str":"","f":0.0}]'

    v = DoubleArrayStruct.new map: [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"map":[[0,1,2],[3,4,5],[6,7,8]]}'

    v = BoolStruct.new b: true
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"b":true}'

    v = BoolStruct.new b: false
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"b":false}'

    v = SymbolStruct.new(sym: :foo)
    expect(TypedSerialize::JSON.marshal(v)).to eq '{"sym":"foo"}'
  end

  it 'jsonから変換できる' do
    obj = TypedSerialize::JSON.unmarshal('{"n":53,"str":"Hello, world!"}', NormalStruct)
    expect(obj.n).to eq 53
    expect(obj.str).to eq 'Hello, world!'

    array = TypedSerialize::JSON.unmarshal('{"arr_struct":[{"n":0,"str":""},{"n":53,"str":"a"}],"arr_int":[0,1,2]}', ArrayStruct)
    expect(array.arr_struct.length).to eq 2
    expect(array.arr_struct[0].n).to eq 0
    expect(array.arr_struct[0].str).to eq ''
    expect(array.arr_struct[1].n).to eq 53
    expect(array.arr_struct[1].str).to eq 'a'
    expect(array.arr_int).to match [0, 1, 2]

    arr = TypedSerialize::JSON.unmarshal('[{"n":53,"str":"Hello, world!"}]', [NormalStruct])
    expect(arr[0].n).to eq 53
    expect(arr[0].str).to eq 'Hello, world!'
    expect(arr.length).to eq 1

    nested = TypedSerialize::JSON.unmarshal('{"nest":{"n":3}}', NestedStruct)
    expect(nested.nest.n).to eq 3

    doubled = TypedSerialize::JSON.unmarshal('{"map":[[0,1,2],[3,4,5],[6,7,8]]}', DoubleArrayStruct)
    expect(doubled.map).to match [[0, 1, 2], [3, 4, 5], [6, 7, 8]]

    bool_true = TypedSerialize::JSON.unmarshal('{"b":true}', BoolStruct)
    expect(bool_true.b).to eq true

    bool_false = TypedSerialize::JSON.unmarshal('{"b":false}', BoolStruct)
    expect(bool_false.b).to eq false

    sym = TypedSerialize::JSON.unmarshal('{"sym":"foo"}', SymbolStruct)
    expect(sym.sym).to eq :foo
  end

  it 'jsonからのパース時、型が違ったらエラーを吐ける' do
    expect { TypedSerialize::JSON.unmarshal('{"n":"53"}', NormalStruct) }.to raise_error TypeError
  end

  it 'jsonからのパース時、値が指定されていなければzero-valueが入る' do
    obj = TypedSerialize::JSON.unmarshal('{}', NormalStruct)
    expect(obj.n).to eq 0
    expect(obj.str).to eq ''
  end

  it 'nilableな構造体型のフィールドにnilが入ってもパースできる' do
    child = Class.new(TypedStruct) do
      define :n, :int
    end

    parent = Class.new(TypedStruct) do
      define :obj, child, allow: 'nil'
    end

    parsed = TypedSerialize::JSON.unmarshal('{"obj":null}', parent)
    expect(parsed.obj).to eq nil

    parsed = TypedSerialize::JSON.unmarshal('{"obj":{"n":1}}', parent)
    expect(parsed.obj.n).to eq 1
  end
end

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

describe 'yaml' do
  it '変換できる' do
    c = Class.new(TypedStruct) do
      define :integer_field, :int
      define :string_field, :string, json: 'string' # FIXME: yamlキーでタグ付けできるようにする
    end

    obj = c.new(integer_field: 3, string_field: 'hello')
    y = TypedSerialize::YAML.marshal(obj)
    expect(y).to eq <<~EOF
      integer_field: 3
      string: hello
    EOF
  end

  it 'パースできる' do
    c = Class.new(TypedStruct) do
      define :integer_field, :int
      define :string_field, :string, json: 'string' # FIXME: yamlキーでタグ付けできるようにする
    end

    y = <<~EOF
      integer_field: 3
      string: hello
    EOF

    obj = TypedSerialize::YAML.unmarshal(y, c)
    expect(obj.integer_field).to eq 3
    expect(obj.string_field).to eq 'hello'
  end
end
