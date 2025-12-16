// register_student.js

const url = 'http://localhost:8000/api/students/register';

const payload = {
  device_id: "hdye4ejtsb_1765888814996",
  name: "Effan",
  falcon_public_key_b64: "CTJdTeGppaYuOBTUteiZsQJoJl1hv0YZ3DRy0YduOdMHlkrUF/nciXhRnnGqbOF96zh40J2YDWTooTFTE2AUdaMgKNoP7FpTTlWnshPrNe5Vl9ZpDUKqKCFF5VNHFTCJA8MbL47klgQm2VEMiZOn2Fd2pAIm+ecwgbGoe62cIhx2qWV30udHZaVDsdK8ZNyc+EjSy0bBz+IiIfhUditJ8KStnhpBVHQCL6t+y8mQK..."
};

async function registerStudent() {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  const data = await res.json();
  console.log('✅ Response:', data);
}

registerStudent().catch(console.error);
