# OnyxEx

[Onyx](https://github.com/johnf9896/onyx) configuration reading library for Elixir

This Elixir library reads configuration YAML files as specified and used by the Onyx CLI tool. You can find the documentation for Onyx CLI [here](https://github.com/johnf9896/onyx).

## Usage

Create an `onyx.yml` file with `onyx init`

Include the dependency in your `mix.exs`

```elixir
{:onyx_ex, github: "johnf9896/onyx_ex", tag: "0.1.0"}
```

Configure the dependency in `config.exs`

```elixir
# format can be :map or :keyword. Default :map
# Specifies the type of complex configuration entries
#
# YAML:
# app:
#   config:
#     foo:
#       bar: xxxx
#       baz: yyyy
#
# Result:
# :map
#   OnyxEx.get!(:foo)
#   %{bar: "xxxx", baz: "yyyy"}
# :keyword
#   OnyxEx.get!(:foo)
#   [bar: "xxxx", baz: "yyyy"]
config :onyx_ex, app: :my_app, format: :keyword
```

Sample configuration files

`onyx.yml`:

```yaml
name: example
description: An example app
container: none
umbrella: true
include:
  - onyx.priv.yml
app:
  config:
    db:
      name: db
      pass: secret
      user: user
      port: 80
      host: localhost
    key: XXXX
apps:
  models:
    config:
      baz: foo
  core:
    config:
      foo: bar
runner:
  valid: []
  default: []

```

`onyx.priv.yml`:

```yaml
app:
  config:
    db:
      port: 8080
    key2: YYYY
apps:
  models:
    config:
      baz: fuz
      ff: sd
  core:
    config:
      haz: faa

```

Getting configuration entries

```elixir
OnyxEx.get(:models, :baz, nil) # fuz
OnyxEx.get(:baz, "default") # fuz, will take the app from config.exs
OnyxEx.get(:bazz, "default") # default
OnyxEx.get!(:db) # Will fallback to app. Will raise error if not found. Returns a map or a keyword list depending on :format
OnyxEx.get!({:db, :port}) # 8080
OnyxEx.get!({:db, :pass}) # secret
```

You can also use sigils

```elixir
import OnyxEx

~o/db/ # Same as OnyxEx.get(:db, nil)
~o/db|pass/ # Same as OnyxEx.get({:db, :pass}, nil)
~o/db/models # Same as OnyxEx.get(:models, :db, nil)
~O/db/ # Same as OnyxEx.get!(:db)
```

License

-------

    Copyright 2018 Jhon Pedroza

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
