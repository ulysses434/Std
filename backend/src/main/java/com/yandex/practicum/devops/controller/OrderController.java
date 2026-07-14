package com.yandex.practicum.devops.controller;

import com.yandex.practicum.devops.dto.OrderProductDto;
import com.yandex.practicum.devops.exception.ResourceNotFoundException;
import com.yandex.practicum.devops.model.Order;
import com.yandex.practicum.devops.model.OrderProduct;
import com.yandex.practicum.devops.model.OrderStatus;
import com.yandex.practicum.devops.service.OrderProductService;
import com.yandex.practicum.devops.service.OrderService;
import com.yandex.practicum.devops.service.ProductService;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.CollectionUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import javax.validation.constraints.NotNull;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final ProductService productService;
    private final OrderService orderService;
    private final OrderProductService orderProductService;
    private final MeterRegistry meterRegistry;

    public OrderController(ProductService productService,
                           OrderService orderService,
                           OrderProductService orderProductService,
                           MeterRegistry meterRegistry) {
        this.productService = productService;
        this.orderService = orderService;
        this.orderProductService = orderProductService;
        this.meterRegistry = meterRegistry;
    }

    @GetMapping
    @ResponseStatus(HttpStatus.OK)
    public @NotNull Iterable<Order> list() {
        return this.orderService.getAllOrders();
    }

    @PostMapping
    public ResponseEntity<Order> create(@RequestBody OrderForm form) {
        List<OrderProductDto> formDtos = form.getProductOrders();
        validateProductsExistence(formDtos);
        Order order = new Order();
        order.setStatus(OrderStatus.PAID.name());
        order = this.orderService.create(order);

        List<OrderProduct> orderProducts = new ArrayList<>();
        for (OrderProductDto dto : formDtos) {
            orderProducts.add(orderProductService.create(new OrderProduct(order, productService.getProduct(dto
              .getProduct()
              .getId()), dto.getQuantity())));
        }

        order.setOrderProducts(orderProducts);
        this.orderService.update(order);
        for (OrderProduct op : orderProducts) {
            String type = op.getProduct().getName();
            meterRegistry.counter("sausage.orders.total", "type", type).increment();
        }

        String uri = ServletUriComponentsBuilder
          .fromCurrentServletMapping()
          .path("/orders/{id}")
          .buildAndExpand(order.getId())
          .toString();
        HttpHeaders headers = new HttpHeaders();
        headers.add("Location", uri);

        return new ResponseEntity<>(order, headers, HttpStatus.CREATED);
    }

    private void validateProductsExistence(List<OrderProductDto> orderProducts) {
        if (orderProducts == null) {
            return;
        }
        List<OrderProductDto> list = orderProducts
          .stream()
          .filter(op -> Objects.isNull(productService.getProduct(op
            .getProduct()
            .getId())))
          .collect(Collectors.toList());

        if (!CollectionUtils.isEmpty(list)) {
            throw new ResourceNotFoundException("Product not found");
        }
    }

    public static class OrderForm {

        private List<OrderProductDto> productOrders;

        public List<OrderProductDto> getProductOrders() {
            return productOrders;
        }

        public void setProductOrders(List<OrderProductDto> productOrders) {
            this.productOrders = productOrders;
        }
    }
}