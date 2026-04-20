const { Router } = require('express');
const ctrl = require('../controllers/pedidos.controller');

const router = Router();

router.get('/info',   ctrl.info);
router.get('/',       ctrl.getAll);
router.get('/:id',    ctrl.getOne);
router.post('/',      ctrl.create);
router.put('/:id',    ctrl.update);
router.delete('/:id', ctrl.remove);

module.exports = router;
