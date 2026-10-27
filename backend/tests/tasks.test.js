'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/prisma');

afterAll(() => prisma.$disconnect());

/** Registers a throwaway user and returns its access token. */
async function newUser(label) {
  const res = await request(app).post('/api/v1/auth/register').send({
    email: `${label}-${Date.now()}-${Math.random().toString(36).slice(2)}@example.test`,
    password: 'a-long-test-password',
  });
  expect(res.status).toBe(201);
  return res.body.accessToken;
}

describe('task CRUD and ownership', () => {
  let userA;
  let userB;
  let taskOfA;

  beforeAll(async () => {
    userA = await newUser('owner-a');
    userB = await newUser('owner-b');
  });

  test('rejects requests without a token', async () => {
    const res = await request(app).get('/api/v1/tasks');
    expect(res.status).toBe(401);
  });

  test('rejects a forged token', async () => {
    const res = await request(app).get('/api/v1/tasks').set('Authorization', 'Bearer not.a.jwt');
    expect(res.status).toBe(401);
  });

  test('User A creates a task', async () => {
    const res = await request(app).post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userA}`)
      .send({ title: 'Review API security', description: 'Check ownership' });
    expect(res.status).toBe(201);
    expect(res.body.item.title).toBe('Review API security');
    taskOfA = res.body.item;
  });

  test('ignores a client-supplied ownerId', async () => {
    const res = await request(app).post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userB}`)
      .send({ title: 'Sneaky', ownerId: taskOfA.ownerId });
    expect(res.status).toBe(201);
    expect(res.body.item.ownerId).not.toBe(taskOfA.ownerId);
  });

  test('User A lists only their own tasks', async () => {
    const res = await request(app).get('/api/v1/tasks?page=1&limit=20')
      .set('Authorization', `Bearer ${userA}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].id).toBe(taskOfA.id);
  });

  test('User B cannot read, update, or delete User A\'s task', async () => {
    const auth = { Authorization: `Bearer ${userB}` };
    const get = await request(app).get(`/api/v1/tasks/${taskOfA.id}`).set(auth);
    const patch = await request(app).patch(`/api/v1/tasks/${taskOfA.id}`).set(auth).send({ completed: true });
    const del = await request(app).delete(`/api/v1/tasks/${taskOfA.id}`).set(auth);
    expect([get.status, patch.status, del.status]).toEqual([404, 404, 404]);

    const stillThere = await request(app).get(`/api/v1/tasks/${taskOfA.id}`)
      .set('Authorization', `Bearer ${userA}`);
    expect(stillThere.status).toBe(200);
    expect(stillThere.body.item.completed).toBe(false);
  });

  test('User A updates and deletes their task', async () => {
    const auth = { Authorization: `Bearer ${userA}` };
    const patch = await request(app).patch(`/api/v1/tasks/${taskOfA.id}`).set(auth).send({ completed: true });
    expect(patch.status).toBe(200);
    expect(patch.body.item.completed).toBe(true);

    const del = await request(app).delete(`/api/v1/tasks/${taskOfA.id}`).set(auth);
    expect(del.status).toBe(204);
  });

  test('enforces pagination bounds', async () => {
    const res = await request(app).get('/api/v1/tasks?limit=1000')
      .set('Authorization', `Bearer ${userA}`);
    expect(res.status).toBe(400);
  });

  test('rejects an empty update', async () => {
    const res = await request(app).patch('/api/v1/tasks/clxxxxxxxxxxxxxxxxxxxxxxx')
      .set('Authorization', `Bearer ${userA}`).send({});
    expect(res.status).toBe(400);
  });

  test('malformed task id gets a safe 400', async () => {
    const res = await request(app).get("/api/v1/tasks/'%20OR%201=1")
      .set('Authorization', `Bearer ${userA}`);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});
