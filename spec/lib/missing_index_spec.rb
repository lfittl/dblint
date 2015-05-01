require 'spec_helper'

describe Dblint::Checks::MissingIndex do
  it 'does not raise an error on non-filtering SELECTs' do
    expect do
      Minion.count
    end.not_to raise_error
  end

  it 'does not raise an error on filtering SELECTs with an index' do
    Minion.create! ident: 'test'
    expect do
      Minion.find_by!(ident: 'test')
    end.not_to raise_error
  end

  it 'does raise an error on filtering SELECTs without an index' do
    Minion.create! name: 'test'
    expect do
      Minion.find_by!(name: 'test')
    end.to raise_error(Dblint::Checks::MissingIndex::Error, /Missing index on/)
  end
end
