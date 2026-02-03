-- Products Table Validation Rules
-- 表名: products

return {
    table_name = 'products',
    description = 'Product management',
    fields = {
        id = {
            type = 'number',
            rules = { 'integer' },
            label = 'Product ID',
            description = 'Primary key'
        },
        name = {
            type = 'string',
            rules = {
                'required',
                { 'length_min', 2 },
                { 'length_max', 200 }
            },
            label = 'Product Name',
            description = 'Product name, 2-200 characters'
        },
        sku = {
            type = 'string',
            rules = {
                'required',
                'alpha_dash',
                { 'length_min', 3 },
                { 'length_max', 50 }
            },
            label = 'SKU',
            description = 'Stock Keeping Unit, unique identifier'
        },
        description = {
            type = 'string',
            rules = {
                { 'length_max', 5000 }
            },
            label = 'Description',
            description = 'Product description, max 5000 characters',
            optional = true
        },
        price = {
            type = 'number',
            rules = {
                'required',
                'numeric',
                { 'min', 0.01 }
            },
            label = 'Price',
            description = 'Product price, must be greater than 0'
        },
        cost_price = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Cost Price',
            description = 'Cost price',
            optional = true
        },
        discount_price = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Discount Price',
            description = 'Discounted price',
            optional = true
        },
        currency = {
            type = 'string',
            rules = {
                { 'length', 3 },
                'alpha',
                { 'default', 'USD' }
            },
            label = 'Currency',
            description = 'Currency code (USD, CNY, EUR, etc.)',
            default = 'USD'
        },
        stock = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 0 }
            },
            label = 'Stock',
            description = 'Inventory quantity',
            default = 0
        },
        category_id = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 1 }
            },
            label = 'Category ID',
            description = 'Product category'
        },
        brand_id = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 1 }
            },
            label = 'Brand ID',
            description = 'Product brand',
            optional = true
        },
        status = {
            type = 'string',
            rules = {
                'in:draft,active,inactive,discontinued'
            },
            label = 'Status',
            description = 'Product status',
            default = 'draft'
        },
        is_featured = {
            type = 'boolean',
            rules = {
                'boolean'
            },
            label = 'Featured',
            description = 'Featured product flag',
            default = false
        },
        is_new = {
            type = 'boolean',
            rules = {
                'boolean'
            },
            label = 'New Arrival',
            description = 'New arrival flag',
            default = false
        },
        weight = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Weight',
            description = 'Product weight in kg',
            optional = true
        },
        unit = {
            type = 'string',
            rules = {
                { 'length_max', 20 }
            },
            label = 'Unit',
            description = 'Weight unit (kg, g, lb, oz)',
            optional = true
        },
        images = {
            type = 'array',
            rules = {
                'array'
            },
            label = 'Product Images',
            description = 'Array of image URLs',
            optional = true
        },
        tags = {
            type = 'string',
            rules = {
                { 'length_max', 500 }
            },
            label = 'Tags',
            description = 'Product tags, comma-separated',
            optional = true
        },
        view_count = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 0 }
            },
            label = 'View Count',
            description = 'Number of views',
            default = 0
        },
        sold_count = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 0 }
            },
            label = 'Sold Count',
            description = 'Number of items sold',
            default = 0
        },
        rating = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 },
                { 'max', 5 }
            },
            label = 'Rating',
            description = 'Average rating (0-5)',
            default = 0
        },
        review_count = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 0 }
            },
            label = 'Review Count',
            description = 'Number of reviews',
            default = 0
        },
        seo_title = {
            type = 'string',
            rules = {
                { 'length_max', 200 }
            },
            label = 'SEO Title',
            description = 'SEO meta title',
            optional = true
        },
        seo_description = {
            type = 'string',
            rules = {
                { 'length_max', 500 }
            },
            label = 'SEO Description',
            description = 'SEO meta description',
            optional = true
        },
        created_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Created At',
            description = 'Creation date'
        },
        updated_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Updated At',
            description = 'Last update date'
        }
    },
    scenarios = {
        create = {
            'name',
            'sku',
            'price',
            'category_id'
        },
        update = {
            'name',
            'price',
            'description',
            'stock',
            'status'
        },
        list = {
            'name',
            'sku',
            'category_id',
            'brand_id',
            'status',
            'price_min',
            'price_max'
        },
        search = {
            'keyword',
            'category_id',
            'price_min',
            'price_max',
            'sort_by',
            'page',
            'per_page'
        }
    }
}
