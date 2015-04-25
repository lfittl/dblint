# async_counter_cache

Re-implements the Rails counter cache's UPDATEs to happen outside of the primary transaction that changes a record. Since that is not atomic anymore, this uses a `COUNT(*)` on the association.

Due to its possible slowness this is run in an ActiveJob by default, meaning the count is not immediately updated.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'async_counter_cache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install async_counter_cache

## Usage

```
has_many :posts, async_counter_cache: :posts_count
```

## Contributing

1. Fork it ( https://github.com/lfittl/async_counter_cache/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
