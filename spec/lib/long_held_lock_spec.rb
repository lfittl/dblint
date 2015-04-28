require 'spec_helper'

describe Dblint::Checks::LongHeldLock do
  it 'raises an error if more than 15 transactions happened after an UPDATE' do
    minion = Minion.create! name: 'test'

    expect do
      Minion.transaction do
        minion.update! name: 'something'
        16.times { Kitten.count }
      end
    end.to raise_error(Dblint::Checks::LongHeldLock::Error)
  end
end
