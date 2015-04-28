require 'spec_helper'

describe Dblint::Checks::LongHeldLock do
  it 'does not raise an error if no UPDATE' do
    expect do
      Minion.transaction do
        16.times { Kitten.count }
      end
    end.not_to raise_error
  end

  it 'does not raise an error if 15 or less transactions happened after an UPDATE' do
    minion = Minion.create! name: 'test'
    expect do
      Minion.transaction do
        8.times { Kitten.count }
        minion.update! name: 'something'
        8.times { Kitten.count }
      end
    end.not_to raise_error
  end

  it 'does not raise an error if the record was created in the transaction' do
    expect do
      Minion.transaction do
        minion2 = Minion.create! name: 'test'
        minion2.update! name: 'something'
        16.times { Kitten.count }
      end
    end.not_to raise_error
  end

  it 'raises an error if more than 15 transactions happened after an UPDATE' do
    minion = Minion.create! name: 'test'
    expect do
      Minion.transaction do
        minion.update! name: 'something'
        16.times { Kitten.count }
      end
    end.to raise_error(Dblint::Checks::LongHeldLock::Error, /Lock on \["minions", \d+\] held for 16 statements/)
  end
end
