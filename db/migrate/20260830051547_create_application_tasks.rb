class CreateApplicationTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :application_tasks do |t|
      t.string :application_name
      t.string :status
      t.text :details

      t.timestamps
    end
  end
end
