-- Orders Table Validation Rules
-- 表名: orders

return {
    table_name = 'orders',
    description = 'Order management',
    fields = {
        id = {
            type = 'number',
            rules = { 'integer' },
            label = 'Order ID',
            description = 'Primary key'
        },
        order_no = {
            type = 'string',
            rules = {
                'required',
                { 'length_min', 10 },
                { 'length_max', 30 },
                'alpha_num'
            },
            label = 'Order Number',
            description = 'Unique order number'
        },
        user_id = {
            type = 'number',
            rules = {
                'required',
                'integer',
                { 'min', 1 }
            },
            label = 'User ID',
            description = 'Customer ID'
        },
        status = {
            type = 'string',
            rules = {
                'in:pending,paid,processing,shipped,delivered,cancelled,refunded'
            },
            label = 'Order Status',
            description = 'Order status',
            default = 'pending'
        },
        payment_status = {
            type = 'string',
            rules = {
                'in:unpaid,paid,refunded,partial_refund'
            },
            label = 'Payment Status',
            description = 'Payment status',
            default = 'unpaid'
        },
        total_amount = {
            type = 'number',
            rules = {
                'required',
                'numeric',
                { 'min', 0.01 }
            },
            label = 'Total Amount',
            description = 'Order total amount'
        },
        discount_amount = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Discount Amount',
            description = 'Discount applied',
            default = 0
        },
        shipping_fee = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Shipping Fee',
            description = 'Shipping cost',
            default = 0
        },
        tax_amount = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Tax Amount',
            description = 'Tax amount',
            default = 0
        },
        currency = {
            type = 'string',
            rules = {
                { 'length', 3 },
                'alpha',
                { 'default', 'USD' }
            },
            label = 'Currency',
            description = 'Currency code',
            default = 'USD'
        },
        receiver_name = {
            type = 'string',
            rules = {
                'required',
                { 'length_min', 2 },
                { 'length_max', 50 },
                'alpha'
            },
            label = 'Receiver Name',
            description = 'Recipient name'
        },
        receiver_phone = {
            type = 'string',
            rules = {
                'required',
                'regex:^1[3-9]%d{9}$'
            },
            label = 'Receiver Phone',
            description = 'Recipient mobile number'
        },
        receiver_tel = {
            type = 'string',
            rules = {
                'regex:^%d{3}-%d{8}$|^%d{4}-%d{7,8}$'
            },
            label = 'Receiver Telephone',
            description = 'Recipient landline',
            optional = true
        },
        receiver_province = {
            type = 'string',
            rules = {
                { 'length_max', 50 }
            },
            label = 'Province',
            description = 'Province/State',
            optional = true
        },
        receiver_city = {
            type = 'string',
            rules = {
                { 'length_max', 50 }
            },
            label = 'City',
            description = 'City',
            optional = true
        },
        receiver_district = {
            type = 'string',
            rules = {
                { 'length_max', 50 }
            },
            label = 'District',
            description = 'District/Area',
            optional = true
        },
        receiver_address = {
            type = 'string',
            rules = {
                'required',
                { 'length_min', 5 },
                { 'length_max', 300 }
            },
            label = 'Address',
            description = 'Detailed address'
        },
        receiver_zipcode = {
            type = 'string',
            rules = {
                { 'length_min', 5 },
                { 'length_max', 10 },
                'numeric'
            },
            label = 'Zip Code',
            description = 'Postal code',
            optional = true
        },
        shipping_method = {
            type = 'string',
            rules = {
                'in:standard,express,same_day'
            },
            label = 'Shipping Method',
            description = 'Shipping method',
            default = 'standard'
        },
        shipping_no = {
            type = 'string',
            rules = {
                { 'length_max', 50 },
                'alpha_num'
            },
            label = 'Tracking Number',
            description = 'Express tracking number',
            optional = true
        },
        payment_method = {
            type = 'string',
            rules = {
                'in:alipay,wechat,bank_card,balance,cod'
            },
            label = 'Payment Method',
            description = 'Payment method',
            default = 'alipay'
        },
        payment_no = {
            type = 'string',
            rules = {
                { 'length_max', 100 },
                'alpha_num'
            },
            label = 'Payment Transaction ID',
            description = 'Payment platform transaction ID',
            optional = true
        },
        paid_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Paid At',
            description = 'Payment time',
            optional = true
        },
        shipped_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Shipped At',
            description = 'Shipping time',
            optional = true
        },
        delivered_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Delivered At',
            description = 'Delivery time',
            optional = true
        },
        user_note = {
            type = 'string',
            rules = {
                { 'length_max', 500 }
            },
            label = 'Customer Note',
            description = 'Customer order note',
            optional = true
        },
        admin_note = {
            type = 'string',
            rules = {
                { 'length_max', 500 }
            },
            label = 'Admin Note',
            description = 'Admin internal note',
            optional = true
        },
        created_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Created At',
            description = 'Order creation time'
        },
        updated_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Updated At',
            description = 'Last update time'
        }
    },
    scenarios = {
        create = {
            'user_id',
            'receiver_name',
            'receiver_phone',
            'receiver_address',
            'payment_method'
        },
        update = {
            'status',
            'receiver_name',
            'receiver_phone',
            'receiver_address',
            'shipping_method',
            'admin_note'
        },
        status_change = {
            'status'
        },
        ship = {
            'shipping_method',
            'shipping_no'
        },
        pay = {
            'payment_method',
            'payment_no'
        },
        search = {
            'order_no',
            'user_id',
            'status',
            'payment_status',
            'created_at_start',
            'created_at_end',
            'page',
            'per_page'
        }
    }
}
