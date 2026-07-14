package com.yandex.practicum.devops.service;

import com.yandex.practicum.devops.model.Order;
import com.yandex.practicum.devops.model.OrderProduct;
import com.yandex.practicum.devops.repository.OrderRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
@Transactional
public class OrderServiceImpl implements OrderService {

    private final OrderRepository orderRepository;
    private final BusinessMetricsService metricsService;
    private final MeterRegistry meterRegistry;

    public OrderServiceImpl(OrderRepository orderRepository,
                            BusinessMetricsService metricsService,
                            MeterRegistry meterRegistry) {
        this.orderRepository = orderRepository;
        this.metricsService = metricsService;
        this.meterRegistry = meterRegistry;
    }

    @Override
    public Iterable<Order> getAllOrders() {
        return this.orderRepository.findAll();
    }

    @Override
    public Order create(Order order) {
        order.setDateCreated(LocalDate.now());
        metricsService.initOrderCounters();
        Order saved = this.orderRepository.save(order);
        // Увеличиваем счётчик для каждого продукта в заказе
        for (OrderProduct op : saved.getOrderProducts()) {
            String type = op.getProduct().getName();
            meterRegistry.counter("sausage.orders.total", "type", type).increment();
        }
        metricsService.orderSausage(saved);
        return saved;
    }

    @Override
    public void update(Order order) {
        this.orderRepository.save(order);
        for (OrderProduct op : order.getOrderProducts()) {
            String type = op.getProduct().getName();
            meterRegistry.counter("sausage.orders.total", "type", type).increment();
        }
        metricsService.orderSausage(order);
    }
}