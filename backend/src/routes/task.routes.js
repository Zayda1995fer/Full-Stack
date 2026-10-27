'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const {
  createTaskSchema,
  updateTaskSchema,
  listTasksSchema,
  taskIdParamsSchema,
} = require('../schemas/task.schema');
const controller = require('../controllers/task.controller');
const { asyncRoute } = require('../utils/async-route');

const router = express.Router();

router.use(requireAuth);

router.get('/', validate(listTasksSchema, 'query'), asyncRoute(controller.list));
router.post('/', validate(createTaskSchema, 'body'), asyncRoute(controller.create));
router.get('/:taskId', validate(taskIdParamsSchema, 'params'), asyncRoute(controller.get));
router.patch(
  '/:taskId',
  validate(taskIdParamsSchema, 'params'),
  validate(updateTaskSchema, 'body'),
  asyncRoute(controller.update),
);
router.delete('/:taskId', validate(taskIdParamsSchema, 'params'), asyncRoute(controller.remove));

module.exports = router;
