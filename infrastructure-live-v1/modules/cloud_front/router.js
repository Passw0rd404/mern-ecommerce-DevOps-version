import cf from 'cloudfront';

const kvs = cf.kvs();

async function handler(event) {
  const request = event.request;

  let version;
  try {
    version = await kvs.get('version');
  } catch (err) {
    return {
      statusCode: 503,
      statusDescription: 'Service Unavailable',
      headers: { 'cache-control': { value: 'no-store' } },
      body: { encoding: 'text', data: 'No frontend release has been deployed yet.' },
    };
  }

  const uri = request.uri;
  const last = uri.substring(uri.lastIndexOf('/') + 1);

  // Files with an extension (JS, CSS, images) keep their path.
  // Everything else is a client-side route, so serve index.html.
  request.uri = '/' + version + (last.includes('.') ? uri : '/index.html');
  return request;
}
