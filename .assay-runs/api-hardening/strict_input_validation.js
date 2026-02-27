// Import necessary modules
const Joi = require('joi');
// Define the schema for input validation
const schema = Joi.object({
  apiPath: Joi.string().required(),
  param1: Joi.string().required(),
  param2: Joi.number().integer().required()
}).options({ abortEarly: false });
// Function to validate the input
function validateInput(input) {
  return schema.validate(input);
}
// Example usage
const input = { apiPath: 'high-risk-api', param1: 'exampleParam', param2: 123 };
const { error, value } = validateInput(input);
if (error) {
  console.error('Validation error:', error.details.map(err => err.message).join('\n'));
} else {
  console