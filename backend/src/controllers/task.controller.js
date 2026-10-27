'use strict';

const { TaskService } = require('../services/task.service');

const service = new TaskService();

/** GET /tasks — lists the authenticated user's tasks. */
async function list(req, res) {
  res.json(await service.list(req.user.id, req.query));
}

/** GET /tasks/:taskId — returns one owned task. */
async function get(req, res) {
  res.json({ item: await service.get(req.user.id, req.params.taskId) });
}

/** POST /tasks — creates a task. Owner always comes from the token, never the body. */
async function create(req, res) {
  const item = await service.create(req.user.id, req.body);
  res.status(201).json({ item });
}

/** PATCH /tasks/:taskId — updates an owned task. */
async function update(req, res) {
  const item = await service.update(req.user.id, req.params.taskId, req.body);
  res.json({ item });
}

/** DELETE /tasks/:taskId — deletes an owned task. */
async function remove(req, res) {
  await service.delete(req.user.id, req.params.taskId);
  res.status(204).end();
}

module.exports = { list, get, create, update, remove };
