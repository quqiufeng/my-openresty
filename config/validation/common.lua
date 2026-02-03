-- Common Validation Rules
-- 通用验证规则定义

return {
    -- 基础类型规则
    types = {
        string = {
            rules = { 'string' },
            label = 'String'
        },
        number = {
            rules = { 'number' },
            label = 'Number'
        },
        integer = {
            rules = { 'integer' },
            label = 'Integer'
        },
        boolean = {
            rules = { 'boolean' },
            label = 'Boolean'
        },
        array = {
            rules = { 'array' },
            label = 'Array'
        },
        email = {
            rules = { 'email' },
            label = 'Email Address'
        },
        url = {
            rules = { 'url' },
            label = 'URL'
        },
        ip = {
            rules = { 'ip' },
            label = 'IP Address'
        },
        date = {
            rules = { 'date' },
            label = 'Date'
        }
    },

    -- 常用字段规则组合
    fields = {
        -- 用户名: 必填, 3-20位字母数字
        username = {
            rules = {
                'required',
                { 'length_min', 3 },
                { 'length_max', 20 },
                'alpha_num'
            },
            label = 'Username'
        },

        -- 邮箱: 必填, 邮箱格式
        email = {
            rules = {
                'required',
                'email',
                { 'length_max', 100 }
            },
            label = 'Email Address'
        },

        -- 密码: 必填, 8-50位
        password = {
            rules = {
                'required',
                { 'length_min', 8 },
                { 'length_max', 50 }
            },
            label = 'Password'
        },

        -- 确认密码
        password_confirmation = {
            rules = {
                'required',
                { 'match', 'password' }
            },
            label = 'Password Confirmation'
        },

        -- 手机号: 中国手机号
        phone = {
            rules = {
                'regex:^1[3-9]%d{9}$'
            },
            label = 'Phone Number'
        },

        -- 电话: 固定电话格式
        tel = {
            rules = {
                'regex:^%d{3}-%d{8}$|^%d{4}-%d{7,8}$'
            },
            label = 'Telephone'
        },

        -- 年龄: 0-150
        age = {
            rules = {
                'integer',
                { 'min', 0 },
                { 'max', 150 }
            },
            label = 'Age'
        },

        -- 金额: 大于等于0
        price = {
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Price'
        },

        -- 正金额: 大于0
        positive_price = {
            rules = {
                'numeric',
                { 'min', 0.01 }
            },
            label = 'Amount'
        },

        -- 数量: 非负整数
        quantity = {
            rules = {
                'integer',
                { 'min', 0 }
            },
            label = 'Quantity'
        },

        -- 百分比: 0-100
        percentage = {
            rules = {
                'numeric',
                { 'min', 0 },
                { 'max', 100 }
            },
            label = 'Percentage'
        },

        -- 状态: 枚举值
        status = {
            rules = {
                'in:active,inactive,pending'
            },
            label = 'Status'
        },

        -- URL地址
        website = {
            rules = {
                'url',
                { 'length_max', 500 }
            },
            label = 'Website'
        },

        -- 邮编
        zipcode = {
            rules = {
                { 'length_min', 5 },
                { 'length_max', 10 },
                'numeric'
            },
            label = 'Zip Code'
        },

        -- QQ号: 5-12位数字
        qq = {
            rules = {
                'regex:^%d{5,12}$'
            },
            label = 'QQ Number'
        },

        -- 微信号: 6-30位字母数字
        wechat = {
            rules = {
                { 'length_min', 6 },
                { 'length_max', 30 },
                'alpha_num'
            },
            label = 'WeChat ID'
        },

        -- 标题: 必填, 2-200字符
        title = {
            rules = {
                'required',
                { 'length_min', 2 },
                { 'length_max', 200 }
            },
            label = 'Title'
        },

        -- 描述: 最大5000字符
        description = {
            rules = {
                { 'length_max', 5000 }
            },
            label = 'Description'
        },

        -- 简介: 最大500字符
        bio = {
            rules = {
                { 'length_max', 500 }
            },
            label = 'Biography'
        },

        -- 内容: 最大10000字符
        content = {
            rules = {
                { 'length_max', 10000 }
            },
            label = 'Content'
        },

        -- 标签: 逗号分隔
        tags = {
            rules = {
                { 'length_max', 500 }
            },
            label = 'Tags'
        },

        -- 身份证号: 18位身份证
        id_card = {
            rules = {
                'regex:^[1-9]%d{5}(18|19|20)%d{2}(0[1-9]|1[0-2])(0[1-9]|[1-2]%d|3[0-1])%d{3}[%dXx]$'
            },
            label = 'ID Card Number'
        },

        -- 银行卡号: 16-19位数字
        bank_card = {
            rules = {
                'regex:^%d{16,19}$'
            },
            label = 'Bank Card Number'
        },

        -- IP地址
        ip_address = {
            rules = {
                'ip'
            },
            label = 'IP Address'
        },

        -- 颜色值: #RRGGBB格式
        color = {
            rules = {
                'regex:^#[0-9A-Fa-f]{6}$'
            },
            label = 'Color'
        },

        -- 经度: -180到180
        longitude = {
            rules = {
                'numeric',
                { 'min', -180 },
                { 'max', 180 }
            },
            label = 'Longitude'
        },

        -- 纬度: -90到90
        latitude = {
            rules = {
                'numeric',
                { 'min', -90 },
                { 'max', 90 }
            },
            label = 'Latitude'
        }
    },

    -- 常用的规则组合
    combinations = {
        -- 登录
        login = {
            email = 'email',
            password = 'password'
        },

        -- 注册
        register = {
            username = 'username',
            email = 'email',
            password = 'password',
            password_confirmation = 'password_confirmation'
        },

        -- 用户基本信息
        user_profile = {
            real_name = { 'alpha', { 'length_min', 2 }, { 'length_max', 50 } },
            phone = 'phone',
            age = 'age',
            bio = 'bio'
        },

        -- 地址信息
        address = {
            receiver_name = { 'required', { 'length_min', 2 }, { 'length_max', 50 } },
            receiver_phone = 'phone',
            receiver_address = { 'required', { 'length_min', 5 }, { 'length_max', 300 } }
        },

        -- 分页参数
        pagination = {
            page = { 'integer', { 'min', 1 }, { 'default', 1 } },
            per_page = { 'integer', { 'min', 1 }, { 'max', 100 }, { 'default', 20 } }
        }
    }
}
