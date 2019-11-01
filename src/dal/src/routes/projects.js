// ./api-v1/paths/worlds.js
export default function() {
  let operations = {
    GET
  };

  function GET(req, res, next) {
    res.status(200).send("Alright!");
  }

  // NOTE: We could also use a YAML string here.
  GET.apiDoc = {
    summary: 'Returns worlds by name.',
    operationId: 'getWorlds',
    responses: {
      200: {
        description: 'A list of worlds that match the requested name.',
        schema: {
          type: 'string',
        }
      },
      default: {
        description: 'An error occurred',
        schema: {
          additionalProperties: true
        }
      }
    }
  };

  return operations;
}
