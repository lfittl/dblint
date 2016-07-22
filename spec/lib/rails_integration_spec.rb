require 'spec_helper'

RSpec.describe Dblint::RailsIntegration do
  subject { Dblint::RailsIntegration.new }

  describe 'private#payload_from_version' do
    describe 'AR version 4' do
      let(:payload) {
        {
          sql: 'SELECT  "users".* FROM "users" WHERE "users"."id" = $1 AND "users"."visibility" = $2 ORDER BY "users"."id" ASC LIMIT 1',
          name: 'User Load',
          connection_id: 70108286766780,
          statement_name: nil,
          binds: [
            [ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new(
              'id',
              nil,
              ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid.new,
              'uuid',
              false,
              'uuid_generate_v4()'),
            '3b12f5f9-3d6c-4fd0-ba18-dc02a2b631af'],
            [ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new(
              'visibility',
              'public',
              ActiveRecord::Type::String.new,
              'character varying',
              false),
            'public']
          ]
        }
      }

      it 'returns payload' do
        expect(subject.send(:payload_from_version, 4, payload)).to eq(payload)
      end
    end

    describe "AR version 5" do
      let(:payload) {
        {
          sql: 'SELECT  "users".* FROM "users" WHERE "users"."id" = $1 AND "users"."visibility" = $2 ORDER BY "users"."id" ASC LIMIT 1',
          name: 'User Load',
          connection_id: 70108286766780,
          statement_name: nil,
          binds: [
            ActiveRecord::Relation::QueryAttribute.new(
              'id',
              '3b12f5f9-3d6c-4fd0-ba18-dc02a2b631af',
              ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid.new
            ),
            ActiveRecord::Relation::QueryAttribute.new(
              'visibility',
              'public',
              ActiveModel::Type::String.new
            )
          ]
        }
      }

      it 'creates backwards compatible version of binds' do
        result = subject.send(:payload_from_version, 5, payload)
        id = result[:binds].first
        visibility = result[:binds].second

        expect(id[0].name).to eq('id')
        expect(id[1]).to eq('3b12f5f9-3d6c-4fd0-ba18-dc02a2b631af')

        expect(visibility[0].name).to eq('visibility')
        expect(visibility[1]).to eq('public')
      end

      it 'preserves base payload attributes' do
        result = subject.send(:payload_from_version, 5, payload)

        expect(result[:sql]).to eq(payload[:sql])
        expect(result[:name]).to eq(payload[:name])
        expect(result[:conection_id]).to eq(payload[:conection_id])
        expect(result[:statement_name]).to eq(payload[:statement_name])
      end
    end
  end
end
