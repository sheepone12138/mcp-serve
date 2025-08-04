import matlab.engine
import numpy as np

def call_pso_optimization(var_range=None):
    """
    调用 MATLAB 的 PSO 优化函数，并处理输出。
    
    Args:
        var_range: 变量范围，格式为 [[min1, max1], [min2, max2], [min3, max3], [min4, max4]]
                  如果为 None，使用默认值。
    
    Returns:
        包含优化结果的字典。
    """
    # 启动 MATLAB 引擎
    eng = matlab.engine.start_matlab()
    
    try:
        # 如果提供了 var_range，则将其转换为 MATLAB 格式
        if var_range is not None:
            matlab_var_range = matlab.double(var_range.tolist())
            print(f"使用自定义参数: {var_range}")
            eng.pso_optimization_full(matlab_var_range, nargout=0)
        else:
            print("使用默认参数")
            eng.pso_optimization_full(nargout=0)
        
        # 捕获 MATLAB 的输出
        results = {}
        
        # 读取最优参数
        if eng.exist('gbest_param.csv', 'file'):
            gbest_param = np.genfromtxt('gbest_param.csv', delimiter=',')
            results['最优归一化参数'] = gbest_param[0, :4].tolist()
            results['最优物理参数'] = gbest_param[1, :4].tolist()
        
        # 读取目标函数值
        if eng.exist('Pareto_result.csv', 'file'):
            pareto_result = np.genfromtxt('Pareto_result.csv', delimiter=',')
            results['加速时间(s)'] = pareto_result[4]
            results['油耗(g/100km)'] = pareto_result[5]
        
        # 读取收敛历史
        if eng.exist('gbest_hist.csv', 'file'):
            gbest_hist = np.genfromtxt('gbest_hist.csv', delimiter=',')
            results['最终目标值'] = gbest_hist[-1]
        
        # 打印结果
        print("\n==== PSO 最优解参数与目标 ====")
        print(f"最优归一化参数: {results['最优归一化参数']}")
        print(f"最优物理参数: 电机功率: {results['最优物理参数'][0]:.2f} kW, 电池容量: {results['最优物理参数'][1]:.2f} kWh, 发动机排量: {results['最优物理参数'][2]:.2f} L, 档位: {results['最优物理参数'][3]:.2f}")
        print(f"加速时间: {results['加速时间(s)']:.2f} s, 油耗: {results['油耗(g/100km)']:.2f} g/100km, 加权目标: {results['最终目标值']:.2f}")
        
        return results
    
    finally:
        # 关闭 MATLAB 引擎
        eng.quit()

# 使用示例
if __name__ == "__main__":
    # 示例 1: 使用默认参数
    print("=== 默认参数优化 ===")
    results1 = call_pso_optimization()
    print("结果:", results1)
    
    # 示例 2: 使用自定义参数
    print("\n=== 自定义参数优化 ===")
    custom_params = [
        [40, 80],   # 电机功率范围
        [15, 35],   # 电池容量范围
        [1.5, 2.2], # 发动机排量范围
        [4, 6]      # 档位数范围
    ]
    results2 = call_pso_optimization(custom_params)
    print("结果:", results2)