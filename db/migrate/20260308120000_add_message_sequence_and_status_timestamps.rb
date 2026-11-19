# frozen_string_literal: true

# Uma só tabela (messages) com: sequência na conversa, quem enviou, status e datas (enviada, recebida, lida, pendente).
class AddMessageSequenceAndStatusTimestamps < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :sequence, :integer
    add_column :messages, :sent_at, :datetime
    add_column :messages, :delivered_at, :datetime
    add_column :messages, :read_at, :datetime

    # Preencher sequence por conversa (1, 2, 3...) e datas a partir do status atual
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          WITH ranked AS (
            SELECT id, conversation_id,
                   ROW_NUMBER() OVER (PARTITION BY conversation_id ORDER BY created_at, id) AS seq
            FROM messages
          )
          UPDATE messages m
          SET sequence = ranked.seq
          FROM ranked
          WHERE m.id = ranked.id;
        SQL
        execute <<-SQL.squish
          UPDATE messages SET sent_at = created_at WHERE status >= 1 AND sent_at IS NULL;
        SQL
        execute <<-SQL.squish
          UPDATE messages SET delivered_at = created_at WHERE status >= 2 AND delivered_at IS NULL;
        SQL
        execute <<-SQL.squish
          UPDATE messages SET read_at = created_at WHERE status >= 3 AND read_at IS NULL;
        SQL
      end
    end

    change_column_null :messages, :sequence, false
    add_index :messages, [ :conversation_id, :sequence ], unique: true, name: "index_messages_on_conversation_id_and_sequence"
  end
end
