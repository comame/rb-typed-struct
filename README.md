# TypedStruct

TypedStruct は実行時に型チェックされる構造体を定義します。

`TypedStruct` を継承したクラスを作成し、`define` メソッドでフィールドを定義します。以下の例では、`User` クラスは文字列型の `name` と整数型の `age` を持つ構造体です。

```ruby
class User < TypedStruct
    define :name, :string
    define :age,  :int
end
```

フィールドへのアクセスはメソッド形式で行います。

```ruby
user = User.new
user.name = 'Alice'
user.age = 25

user.name # => 'Alice'
user.age  # => 25
```

構造体のインスタンス化時に初期値を設定できます。

```ruby
user = User.new(name: 'Bob', age: 30)

user.name # => 'Bob'
user.age  # => 30
```

定義された型とは異なる値を代入しようとすると、エラーとなります。

```ruby
user = User.new

user.age = 'twenty-five'
# => 'TypedStruct#assign!': cannot assign "twenty-five" to User.age (TypeError)
```

## 型定義

`define` メソッドの第二引数は、様々な型定義を受け付けます。

プリミティブ型はシンボルで指定します (例 `:int`, `:bool`, `:float`, `:string`, `:symbol`)。

```ruby
class User < TypedStruct
    define :name,           :string
    define :age,            :int
    define :email_verified, :bool
    define :type,           :symbol
end
```

他の構造体を指定することもできます。

```ruby
class StructA
    # ...
end

class StructB
    define :struct_a, StructA
end
```

配列型も定義できます。

```ruby
class Post
    define :tags, [:string]
    # ...
end
```

任意の値を受け付けるには、`:any` を指定します。

## nil 許容型

デフォルトでは、`:any` 以外のあらゆるフィールドは `nil` を許容しません。

```ruby
class User
    define :name, :string
end

User.new(name: nil)
# => 'TypedStruct#assign!': cannot assign nil to User.name (TypeError)
```

`nil` をの代入を許容するには、`define` メソッドの第三引数に `allow: 'nil'` (注: `'nil'` は文字列リテラル) を指定します。

```ruby
class User
    define :name, :string, allow: 'nil'
end

u = User.new(name: nil)
u.name # => nil
```

`nil` 代入を許容したフィールドの初期値は `nil` となることに注意してください。

```ruby
class User
    define :name, :string, allow: 'nil'
end

u = User.new
u.name # => nil
```

## タグ

先ほど示したように、`define` メソッドの第三引数にはそのフィールドのオプションを指定できます。これをタグと呼びます。

## JSON

構造体を JSON にエンコード、または JSON からデコードできます。

デコード時には第2引数にデコード先の型を指定します。デコード時の型チェック・代入ルールは、構造体のインスタンス化時の挙動に準じます。

```ruby
class User
    define :name, :string
    define :age,  :int
end

u = User.new(name: 'Alice', age: 25)
TypedSerialize::JSON.marshal(u)
# => '{"name":"Alice","age":25}'

TypedSerialize::JSON.unmarshal('{"name":"Bob","age":30}', User)
# => User.new(name: 'Bob', age: 30)

TypedSerialize::JSON.unmarshal('[{"name":"Alice","age":25},{"name":"Bob","age":30}]', [User])
# => [User.new(name: 'Alice', age: 25), User.new(name: 'Bob', age: 30)]
```

タグを利用して変換の制御ができます (Go 言語の encoding/json パッケージを参考)。

```ruby
class User
    # JSON のキーが "user_name" になる
    define :name, :string, json: 'user_name'

    # JSON のキーが "emailVerified" になり、ゼロ値だったときはJSONから省略される
    define :email_verified, :bool, json: 'emailVerified,omitempty'

    # JSON のキーは指定せず (= "active" のまま)、ゼロ値だったときはJSONから省略される
    define :active, :bool, json: ',omitempty'

    # JSON への変換時 (エンコード・デコード共に) 無視される
    define :password_hash, :string, json: '-'

    # JSON のキーが "-" になる
    define :hyphen, :string, json: '-,'
end
```
