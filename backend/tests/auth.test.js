'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/prisma');

afterAll(() => prisma.$disconnect());

describe('registration and login', () => {
  const email = `auth-${Date.now()}@example.test`;
  const password = 'a-long-test-password';

  test('registers a new account and returns a token pair', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ email, password });
    expect(res.status).toBe(201);
    expect(typeof res.body.accessToken).toBe('string');
    expect(typeof res.body.refreshToken).toBe('string');
    expect(res.body.passwordHash).toBeUndefined();
  });

  test('rejects a duplicate email with 409', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ email, password });
    expect(res.status).toBe(409);
  });

  test('rejects short passwords with 400', async () => {
    const res = await request(app).post('/api/v1/auth/register')
      .send({ email: `short-${Date.now()}@example.test`, password: 'short' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  test('uses the same generic message for wrong password and unknown email', async () => {
    const wrongPassword = await request(app).post('/api/v1/auth/login')
      .send({ email, password: 'not-the-right-password' });
    const unknownEmail = await request(app).post('/api/v1/auth/login')
      .send({ email: `nobody-${Date.now()}@example.test`, password });
    expect(wrongPassword.status).toBe(401);
    expect(unknownEmail.status).toBe(401);
    expect(wrongPassword.body.error.message).toBe(unknownEmail.body.error.message);
  });

  test('normalizes email case on login', async () => {
    const res = await request(app).post('/api/v1/auth/login')
      .send({ email: email.toUpperCase(), password });
    expect(res.status).toBe(200);
  });

  test('malformed JSON returns a safe 400 without internals', async () => {
    const res = await request(app).post('/api/v1/auth/login')
      .set('Content-Type', 'application/json')
      .send('{"email": broken');
    expect(res.status).toBe(400);
    expect(JSON.stringify(res.body)).not.toMatch(/stack|SyntaxError/i);
  });
});
