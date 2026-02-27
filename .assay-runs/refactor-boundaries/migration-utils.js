// Utility functions for handling migrations
module.exports = {
  createTable: (tableName, columns) => {
    return `CREATE TABLE ${tableName} (${columns.join(', ')});`;
  },
  addColumn: (tableName, columnName, dataType)