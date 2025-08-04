function pso_optimization_full()
    % 参数设置
    n_var = 4;
    var_range = [
        30, 90;     % 电机功率（kW）
        10, 40;     % 电池容量（kWh）
        1.0, 2.5;   % 发动机排量（L）
        3, 7        % 档位数
    ];
    lb = zeros(1, n_var); % 归一化下界
    ub = ones(1, n_var);  % 归一化上界

    % PSO参数
    pop_size = 30;
    max_iter = 100;
    w = 0.6;         % 惯性权重
    c1 = 1.5;        % 个体学习因子
    c2 = 1.5;        % 群体学习因子
    max_velocity = 0.1; % 最大速度限制

    % 初始化
    X = rand(pop_size, n_var); % 归一化粒子位置
    V = zeros(pop_size, n_var); % 速度
    pbest = X;
    pbest_val = inf(pop_size, 1);

    gbest = zeros(1, n_var);
    gbest_val = inf;

    % 记录历史
    gbest_hist = zeros(max_iter, 1);

    for iter = 1:max_iter
        for i = 1:pop_size
            % 计算目标函数
            [obj, feasible] = pso_objective(X(i,:), var_range);
            % 约束不可行则惩罚
            if ~feasible
                obj = obj + 1e6;
            end
            % 更新个体最优
            if obj < pbest_val(i)
                pbest(i,:) = X(i,:);
                pbest_val(i) = obj;
            end
            % 更新全局最优
            if obj < gbest_val
                gbest = X(i,:);
                gbest_val = obj;
            end
        end

        % 更新速度和位置
        for i = 1:pop_size
            V(i,:) = w*V(i,:) + c1*rand(1,n_var).*(pbest(i,:)-X(i,:)) + c2*rand(1,n_var).*(gbest-X(i,:));
            % 速度限制
            V(i,:) = min(max(V(i,:), -max_velocity), max_velocity);
            X(i,:) = X(i,:) + V(i,:);
            % 边界处理
            X(i,:) = min(max(X(i,:), lb), ub);
        end

        gbest_hist(iter) = gbest_val;
        if mod(iter, 10) == 0 || iter == 1
            fprintf('迭代 %d, 当前最优目标值: %.4f\n', iter, gbest_val);
        end
    end

    % 输出最优解
    [~, f, ~] = pso_objective(gbest, var_range);
    x_real = zeros(1, n_var);
    for j = 1:n_var
        x_real(j) = gbest(j) * (var_range(j,2) - var_range(j,1)) + var_range(j,1);
    end
    fprintf('\n最优归一化参数: %s\n', mat2str(gbest, 4));
    fprintf('最优物理参数: 电机功率: %.2f kW, 电池容量: %.2f kWh, 发动机排量: %.2f L, 档位: %.2f\n', x_real(1), x_real(2), x_real(3), x_real(4));
    fprintf('加速时间: %.2f s, 油耗: %.2f g/100km, 加权目标: %.2f\n', f(1), f(2), gbest_val);

    % 绘制收敛曲线
    figure;
    plot(gbest_hist, 'LineWidth', 2);
    xlabel('迭代次数');
    ylabel('全局最优目标值');
    title('PSO收敛曲线');
    grid on;

    % 保存最优结果和收敛历史
    save('pso_result.mat', 'gbest', 'x_real', 'gbest_val', 'f', 'gbest_hist');
    csvwrite('gbest_hist.csv', gbest_hist);
    csvwrite('gbest_param.csv', [gbest; x_real]);

    %% ========== NSGA2风格结果导出 ==========

    % 1. 保存所有粒子的最终参数和目标
    all_params = X; % 归一化参数
    all_objectives = zeros(pop_size, 2);
    for i = 1:pop_size
        [~, fval, ~] = pso_objective(X(i,:), var_range);
        all_objectives(i,:) = fval;
    end
    all_header = {'P_m_norm', 'C_batt_norm', 'D_eng_norm', 'gear_norm', 'T_s', 'Fuel'};
    all_result = [all_params, all_objectives];
    writecell(all_header, 'all_solutions_header.csv');
    writematrix(all_result, 'all_solutions_result.csv');

    % 2. 保存最优解参数和目标
    pareto_header = {'P_m_norm', 'C_batt_norm', 'D_eng_norm', 'gear_norm', 'T_s', 'Fuel'};
    pareto_result = [gbest, f];
    writecell(pareto_header, 'Pareto_header.csv');
    writematrix(pareto_result, 'Pareto_result.csv');

    % 3. 保存收敛曲线图片
    saveas(gcf, 'pso_converge.png');
    disp('收敛曲线图片已保存为: pso_converge.png');

    % 4. 控制台输出最优解详细信息
    fprintf('\n==== PSO最优解参数与目标 ====');
    disp(pareto_result);
    fprintf('归一化参数: %s\n', mat2str(gbest, 4));
    fprintf('物理参数: 电机功率: %.2f kW, 电池容量: %.2f kWh, 发动机排量: %.2f L, 档位: %.2f\n', x_real(1), x_real(2), x_real(3), x_real(4));
    fprintf('加速时间: %.2f s, 油耗: %.2f g/100km, 加权目标: %.2f\n', f(1), f(2), gbest_val);
end

function [obj, f, feasible] = pso_objective(x, var_range)
    % 反归一化
    n_var = size(var_range, 1);
    x_real = zeros(1, n_var);
    for j = 1:n_var
        x_real(j) = x(j) * (var_range(j,2) - var_range(j,1)) + var_range(j,1);
    end
    % 构造个体结构体，复用evaluate_objective
    ind = struct('var', x, 'f', [], 'g', [], 'rank', 0, 'crowd_dist', 0);
    ind = evaluate_objective(ind, var_range);
    f = ind.f; % [加速时间, 油耗]
    g = ind.g; % 约束
    % 单目标加权
    % 归一化目标函数
    normalized_obj = normalize_objective(f);
    obj = 0.7 * normalized_obj(1) + 0.3 * normalized_obj(2);
    % 约束可行性
    feasible = all(g <= 1e-6); % 允许极小数值误差
end

function normalized_obj = normalize_objective(f)
    % 假设加速时间的范围是 [0, 10] 秒，油耗的范围是 [0, 1000] g/100km
    t_acc_max = 10;
    fuel_max = 1000;
    normalized_obj = [(f(1) / t_acc_max), (f(2) / fuel_max)];
end

function population = evaluate_objective(population, var_range)
    % 评价目标函数和约束条件，更新 population 的 f/g 字段
    % 输入:
    % population: 个体结构体数组，每个包含 var（已归一化）
    % var_range: 每个变量的上下界矩阵 [n_var × 2]
    % 输出:
    % population: 补全后的结构体数组，含字段 f（目标）、g（约束）
    %% === 加载必要数据 ===
    try
        load('engine_map_data.mat'); % 需含 Ti, ni, bi（扭矩矩阵、转速、燃油消耗率矩阵）
        load('UDDS_cycle.mat'); % 需含 V_UDDS 工况速度 [km/h]
    catch ME
        error('无法加载必要的数据文件: %s', ME.message);
    end
    % 常量定义
    v_max_limit = 180; % 最大车速限制 km/h
    max_grade_limit = 30; % 最大爬坡度 %
    % 车辆参数
    m = 1600; % 整车质量 kg
    r = 0.3; % 轮胎半径 m
    g = 9.81; % 重力加速度
    Cr = 0.01; % 滚阻系数
    rho = 1.2; % 空气密度 kg/m3
    A = 2.0; % 迎风面积 m^2
    Cd = 0.3; % 阻力系数
    eff = 0.9; % 传动系统效率
    V = max(V_UDDS, 5); % 工况速度，防止0除
    num_individuals = length(population);
    n_var = length(var_range);
    for i = 1:num_individuals
        %% === 反归一化变量 ===
        x_norm = population(i).var;
        x = zeros(1, n_var);
        for j = 1:n_var
            x_norm(j) = max(0, min(1, x_norm(j)));
            x(j) = x_norm(j) * (var_range(j,2) - var_range(j,1)) + var_range(j,1);
        end
        % 解包变量
        motor_power = x(1); % 电机峰值功率（kW）
        battery_capacity = x(2); % 电池容量（kWh）
        engine_disp = x(3); % 发动机排量（L）
        gear_number = max(1, round(x(4))); % 变速器档位数（整数，至少为1）
        %% === 目标1：0—50 km/h 起步加速时间 ===
        v_target = 50 / 3.6; % m/s
        v = 0:0.5:v_target; % 速度从 0 到 v_target，步长为 0.5 m/s
        a = zeros(size(v)); % 加速度数组初始化
        
        for k = 1:length(v)
            gear_ratio = 4.5 / gear_number; % 变速器传动比
            final_drive = 4.1; % 主减速比
            total_ratio = gear_ratio * final_drive; % 总传动比
            max_torque = motor_power * 1000 / (2 * pi * 3000 / 60); % 电机最大扭矩（Nm）
            wheel_torque = max_torque * total_ratio * eff; % 车轮扭矩
            F_trac = wheel_torque / r; % 牵引力（N）
            F_resist = m * g * Cr + 0.5 * rho * Cd * A * v(k)^2; % 阻力（N）
            a(k) = max((F_trac - F_resist) / m, 0.1); % 最小加速度为 0.1 m/s²
        end
        
        t_acc = trapz(v, 1 ./ a); % 通过数值积分计算加速时间（秒）
        if isnan(t_acc) || isinf(t_acc) || t_acc <= 0
            t_acc = 100; % 设置一个较大的惩罚值
        end
        %% === 目标2：UDDS 工况下百公里油耗估算 ===
        try
            engine_power_factor = engine_disp / 2.0; % 发动机排量影响因子
            motor_power_factor = motor_power / 60.0; % 电机功率影响因子
            base_fuel_consumption = 250 + 50 * engine_power_factor; % 基础油耗（g/100km）
            cycle_time = length(V) * 0.1; % 工况时间（秒）
            total_distance = sum(V) / 3600; % 总行驶距离（km）
            avg_power = motor_power * motor_power_factor * engine_power_factor; % 平均功率
            total_fuel = avg_power * base_fuel_consumption * cycle_time / 3600; % 总燃油消耗（g）
            if total_distance > 0
                fuel_per_100km = total_fuel / total_distance * 100; % 百公里油耗（g/100km）
            else
                fuel_per_100km = 1000; % 如果总距离为零，设置一个较大的惩罚值
            end
        catch
            fuel_per_100km = 1000; % 如果计算失败，设置一个较大的惩罚值
        end
        if isnan(fuel_per_100km) || isinf(fuel_per_100km) || fuel_per_100km <= 0
            fuel_per_100km = 1000;
        end
        %% === 约束处理 ===
        max_velocity = motor_power * 1000 * eff * r / (m * g * Cr); % 简化估算
        c1 = max(0, max_velocity - v_max_limit); % > 0表示违约
        F_max = motor_power * 1000 / v_target;
        grade = asin(max(0, (F_max - m * g * Cr) / (m * g))) * 100; % %
        c2 = max(0, grade - max_grade_limit);
        %% === 更新个体结构体 ===
        population(i).f = [t_acc, fuel_per_100km]; % 两目标函数
        population(i).g = [c1, c2]; % 两个约束条件
        population(i).rank = 0;
        population(i).crowd_dist = 0;
    end
end 