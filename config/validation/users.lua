-- Users Table Validation Rules
-- 表名: users

return {
    table_name = 'users',
    description = 'User registration and profile management',
    fields = {
        id = {
            type = 'number',
            rules = { 'integer' },
            label = 'User ID',
            description = 'Primary key'
        },
        username = {
            type = 'string',
            rules = {
                'required',
                { 'length_min', 3 },
                { 'length_max', 20 },
                'alpha_num'
            },
            label = 'Username',
            description = 'Unique username, 3-20 characters, letters and numbers only'
        },
        email = {
            type = 'string',
            rules = {
                'required',
                'email',
                { 'length_max', 100 }
            },
            label = 'Email Address',
            description = 'Valid email address, max 100 characters'
        },
        password = {
            type = 'string',
            rules = {
                'required',
                { 'length_min', 8 },
                { 'length_max', 50 }
            },
            label = 'Password',
            description = 'User password, 8-50 characters',
            sanitize = true
        },
        password_confirmation = {
            type = 'string',
            rules = {
                'required',
                { 'match', 'password' }
            },
            label = 'Password Confirmation',
            description = 'Must match password field'
        },
        real_name = {
            type = 'string',
            rules = {
                { 'length_min', 2 },
                { 'length_max', 50 },
                'alpha'
            },
            label = 'Real Name',
            description = 'Real name, 2-50 letters only',
            optional = true
        },
        phone = {
            type = 'string',
            rules = {
                'regex:^1[3-9]%d{9}$'
            },
            label = 'Phone Number',
            description = 'Valid Chinese mobile number',
            optional = true
        },
        tel = {
            type = 'string',
            rules = {
                'regex:^%d{3}-%d{8}$|^%d{4}-%d{7,8}$'
            },
            label = 'Telephone',
            description = 'Format: 010-12345678 or 0512-1234567',
            optional = true
        },
        age = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 0 },
                { 'max', 150 }
            },
            label = 'Age',
            description = 'User age, 0-150',
            optional = true
        },
        gender = {
            type = 'string',
            rules = {
                'in:male,female,other'
            },
            label = 'Gender',
            description = 'Gender: male, female, or other',
            optional = true
        },
        avatar = {
            type = 'string',
            rules = {
                'url',
                { 'length_max', 500 }
            },
            label = 'Avatar URL',
            description = 'Avatar image URL',
            optional = true
        },
        status = {
            type = 'string',
            rules = {
                'in:active,inactive,banned'
            },
            label = 'Status',
            description = 'Account status',
            default = 'inactive'
        },
        role = {
            type = 'string',
            rules = {
                'in:user,admin,moderator'
            },
            label = 'Role',
            description = 'User role',
            default = 'user'
        },
        points = {
            type = 'number',
            rules = {
                'integer',
                { 'min', 0 }
            },
            label = 'Points',
            description = 'User points',
            default = 0
        },
        balance = {
            type = 'number',
            rules = {
                'numeric',
                { 'min', 0 }
            },
            label = 'Balance',
            description = 'Account balance',
            default = 0
        },
        bio = {
            type = 'string',
            rules = {
                { 'length_max', 500 }
            },
            label = 'Biography',
            description = 'User bio, max 500 characters',
            optional = true
        },
        website = {
            type = 'string',
            rules = {
                'url',
                { 'length_max', 200 }
            },
            label = 'Website',
            description = 'Personal website URL',
            optional = true
        },
        wechat = {
            type = 'string',
            rules = {
                { 'length_min', 6 },
                { 'length_max', 30 },
                'alpha_num'
            },
            label = 'WeChat',
            description = 'WeChat ID',
            optional = true
        },
        qq = {
            type = 'string',
            rules = {
                'regex:^%d{5,12}$'
            },
            label = 'QQ Number',
            description = 'Valid QQ number (5-12 digits)',
            optional = true
        },
        created_at = {
            type = 'string',
            rules = {
                'date'
            },
            label = 'Created At',
            description = 'Registration date'
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
            'username',
            'email',
            'password',
            'password_confirmation'
        },
        update = {
            'username',
            'email',
            'real_name',
            'phone',
            'age',
            'gender',
            'bio'
        },
        login = {
            'email',
            'password'
        },
        profile = {
            'real_name',
            'phone',
            'age',
            'gender',
            'bio',
            'website',
            'wechat',
            'qq'
        },
        password_change = {
            'password',
            'password_confirmation'
        }
    }
}
