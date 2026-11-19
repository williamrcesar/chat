# frozen_string_literal: true

# Shift message status values so we can use 0 for "pending" (clock icon):
# old 0 (sent) -> 1, old 1 (delivered) -> 2, old 2 (read) -> 3.
# New messages keep default 0 = pending (na fila).
class AddPendingMessageStatus < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL.squish
      UPDATE messages SET status = status + 1;
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE messages SET status = status - 1 WHERE status > 0;
    SQL
  end
end
