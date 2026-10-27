'use strict';

const repository = require('../repositories/task.repository');

/** Builds the 404 used when a task does not exist or belongs to someone else. */
function notFound() {
  const error = new Error('Task not found.');
  error.status = 404;
  error.code = 'NOT_FOUND';
  return error;
}

/**
 * Task business operations with ownership enforcement.
 */
class TaskService {
  /**
   * Lists the user's tasks with pagination.
   *
   * @param {string} userId - Authenticated user ID.
   * @param {{page: number, limit: number}} pagination - Validated page options.
   * @returns {Promise<object>} Paginated task result.
   */
  async list(userId, { page, limit }) {
    const items = await repository.listByOwner(userId, (page - 1) * limit, limit);
    return { items, page, limit };
  }

  /** Returns one owned task or throws 404. */
  async get(userId, taskId) {
    const task = await repository.findOwned(userId, taskId);
    if (!task) throw notFound();
    return task;
  }

  /** Creates a task owned by the authenticated user. */
  create(userId, data) {
    return repository.create(userId, data);
  }

  /** Updates one task owned by the authenticated user. */
  async update(userId, taskId, data) {
    const updated = await repository.updateOwned(userId, taskId, data);
    if (!updated) throw notFound();
    return updated;
  }

  /** Deletes one task owned by the authenticated user. */
  async delete(userId, taskId) {
    const deleted = await repository.deleteOwned(userId, taskId);
    if (!deleted) throw notFound();
  }
}

module.exports = { TaskService };
